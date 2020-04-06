---
title: "Egressトラフィック監視"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

サービスメッシュについて考える1つの方法は、ドメイン制御です。 Istio[サイドカーインジェクション](https://istio.io/docs/ops/deployment/architecture/#components)が有効になっているKubernetesのNamespaceで、Pod間のすべてのトラフィックを[監視](https://istio.io/docs/tasks/observability/)し、セキュリティポリシーを[適用](https://istio.io/docs/tasks/security/authorization/authz-http/)できます。

しかし、メッシュの外側にあるアップストリームサービスはどうでしょうか。どのサービスが外部APIを呼び出すかを実行時にどうやって決定するのでしょうか？サービスが書き込んでいるデータベースインスタンスをどのようにして知るのでしょうか？または、メッシュ内のサービスが独自の地理的領域内のトラフィックのみを送信していることをどのように確認するのでしょうか？こうしたことは、[IstioのEgress監視](https://istio.io/blog/2019/monitoring-external-service-traffic/) が解決します。

*Egress*は*出口*を意味します。この場合、Egressトラフィックとは、Istioメッシュから出る必要があるリクエストを意味します。 デフォルトですべてのEgressトラフィックを[Istioがブロックした](https://archive.istio.io/v1.0/docs/tasks/traffic-management/egress/)時期がありました。サービスがアクセスする必要があるすべての外部ホストをホワイトリストに登録するには、[`ServiceEntry`](https://istio.io/docs/tasks/traffic-management/egress/egress-control/#access-an-external-http-service)を手動で作成する必要がありました。ServiceEntryは、Istioのサービスレジストリに外部ホストを追加します。これはIstio 1.3で変更され、`REGISTRY_ONLY` Egressポリシーがデフォルトで [`ALLOW_ANY`](https://istio.io/docs/tasks/traffic-management/egress/egress-control/#envoy-passthrough-to-external-services) になりました。このため、現在メッシュ内サービスは `ServiceEntry` を必要とせずに、外部サービスに自由にアクセスできます。

メッシュにどのIstioEgressオプションを選択しても、IstioはすべてのEgressトラフィックを監視できます。また、[専用のEgressゲートウェイ](https://istio.io/docs/tasks/traffic-management/egress/egress-gateway/#use-case)プロキシを必要とせずに、ワークロードのサイドカープロキシを通してこのEgressトラフィックを監視できます。それがどのように機能するか見てみましょう。

![](/images/ptbh-diagram.png)

この例では、ユーザーがレシピを共有できるWebサイトを構築しました。コストを最適化するために、ウェブフロントエンドはサーバーレス機能としてKubernetesの外で実行されます。ユーザーがレシピを追加すると、フロントエンドはKubernetesクラスター内のIDジェネレーターサービス（`idgen`）を呼び出して、そのレシピのIDを作成します。`idgen` はデフォルトのIstio IngressGatewayを介して公開され、`httpbin` と呼ばれる外部APIから[ランダムなID](http://httpbin.org/uuid)を取得します。

## オプション1 - Passthrough

まず、Egressのデフォルト `ALLOW_ANY` オプションを指定したIstioインストールを使用してみましょう。これは、追加の構成なしで、`idgen` の `httpbin` への要求が許可されることを意味します。 `ALLOW_ANY` が有効になっている場合、Istioは、`idgen` のサイドカープロキシによって適用される `PassthroughCluster` と呼ばれるEnvoyクラスターを使用して、Egressトラフィックを監視します。

Envoy[クラスター](https://jvns.ca/blog/2018/10/27/envoy-basics/)は、エンドポイントのバックエンド（または「アップストリーム」）セットであり、外部サービスを表します。 IstioサイドカーEnvoyプロキシは、アプリケーションコンテナーからのインターセプトされたリクエストにフィルターを適用します。これらのフィルターに基づいて、Envoyは特定のルートにトラフィックを送信します。ルートは、トラフィックを送信するクラスターを指定します。

Istio `Passthrough` クラスターは、バックエンドが[元のリクエストの宛先](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/service_discovery#original-destination)になるように設定されています。したがって、Egressトラフィックで `ALLOW_ANY` が有効になっている場合、Envoyは単に `idgen` のリクエストを `httpbin` に「パススルー」します。

この構成では、IngressGatewayを介してレシピIDリクエストを送信すると、`idgen` は `httpbin` を正常に呼び出すことができます。このトラフィックは、Kialiサービスグラフで `PassthroughCluster` トラフィックとして表示されます。`httpbin` が独自のサービスレベルのテレメトリを取得するには、`ServiceEntry` を追加する必要があります。（後ほど行います。）

![](/images/ptbh-kiali-passthrough.png)

しかし、Prometheusをドリルダウンして、`istio_total_requests` メトリクスを見つけると、`PassthroughCluster` トラフィックが `httpbin.org` と呼ばれる `destinationservice` に向かっていることがわかります。

![](/images/ptbh-prom-passthrough.png)

## オプション2 - REGISTRY_ONLY、no ServiceEntry

ここで、httpbin の `ServiceEntry` を追加する前に、すべてのEgressトラフィックをロックしたいとします。これを行うには、送信トラフィックの[グローバルインストールオプション](https://istio.io/docs/reference/config/installation-options/)を `REGISTRY_ONLY` に更新し、Istioインストールマニフェストを再適用します。

今度は、[`BlackHole`](https://istio.io/blog/2019/monitoring-external-service-traffic/#what-are-blackhole-and-passthrough-clusters)という新しいクラスターが登場します。ブラックホールクラスターは、IPエンドポイントのないバックエンドです。 `BlackHoleCluster` にルーティングされたリクエストはEnvoyによってドロップされ、`502: Bad Gateway` エラーが返されます。実際には、Egressリクエストをドロップするサイドカープロキシのコレクションは、`REGISTRY_ONLY` ポリシーが適用される方法です。

`REGISTRY_ONLY` オプションを有効にしてIstioを再インストールし、`idgen` Podを再デプロイすると、`BlackHoleCluster` がリクエストをインターセプトしていることがわかります。赤いグラフの端は、HTTPリクエストが完了しないことを意味します-トラフィックは目的の `httpbin.org` エンドポイントに到達できません。

![](/images/ptbh-kiali-blackhole.png)

Prometheusでは、`istio_total_requests` メトリクスが `BlackHoleCluster` トラフィックを考慮していることがわかります。実際には、このメトリクスにアラートを設定して、クラスター内のサービスによって試みられた[data exfiltration](https://en.wikipedia.org/wiki/Data_exfiltration)を検出できます。このモードでは、Prometheusはブロックされたリクエストの送信元と（試行された）宛先の両方のワークロードを通知できます。

![](/images/ptbh-prom-blackhole.png)

## Option 3 - `REGISTRY_ONLY` with ServiceEntry

ここで、`idgen` が外部APIを呼び出すための承認を得たとしましょう。 Isioレジストリに `httpbin` を追加する `ServiceEntry` の作成を承認しました。:

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-ext
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_EXTERNAL
```

これで、リクエストがメッシュを正常に脱出し、`BlackHoleCluster` によってドロップされていないことがわかります。:

![](/images/ptbh-kiali-serviceentry.png)

また、ServiceEntryを使用すると、Istioは、Kubernetesクラスターの外にあり、制御ドメインの一部ではありませんが、httpbinを別のメッシュサービスとして扱います。これで、`httpbin` 専用のテレメトリを取得できるようになりました。別の外部サービスを追加すると、サービスグラフに独自の別個のノードとして表示されます。

Egressトラフィック監視について詳しく学ぶ：
- [Istioブログ：Neeraj Poddarによる、ブロックされたパススルー外部サービストラフィックの監視](https://istio.io/blog/2019/monitoring-external-service-traffic/)
- [Istio Docs：デフォルトの指標](https://istio.io/docs/reference/config/policy-and-telemetry/metrics/)
- [Envoy Basics、by Julia Evans](https://jvns.ca/blog/2018/10/27/envoy-basics/)