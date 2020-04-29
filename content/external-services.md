---
title: External Services
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

[Service Mesh](https://istio.io/docs/concepts/what-is-istio/#what-is-a-service-mesh) はよく1つの環境 - 例えば、1つの Kubernetes クラスタ - 全体に及びます。また、その環境で接続されているすべてのサービスがメッシュの管理ドメインを形成し、そこからメトリクスを見たりポリシーを設定できます。

しかし、クラスタの**外部**でもサービスを実行している場合や、外部 API に依存している場合はどうでしょうか。

心配は要りません。Istio は [`ServiceEntry`](https://istio.io/docs/concepts/traffic-management/#service-entries) と呼ばれるリソースを提供します。これにより、それがあなたの所有するサービスでなくても外部サービスを論理的にあなたのメッシュへ取り込むことができます。

外部ホスト名の ServiceEntry を作成すると、その外部サービスに到達するまでのメトリクスとトレースを表示できます。これらの外部サービスに[リトライロジック](/retry/)などのトラフィックポリシーを設定することもできます。`ServiceEntries` を追加すると、Istio 管理ドメインの範囲が効果的に広がります。例を見てみましょう。

![external currency service](/images/ext-currency.png)

ここではユーザの居住地に基づいて商品の価格を変換する `currency` サービスを備えた、グローバルの EC サイトを動かしています。サードパーティの通過変換 API である [ヨーロッパ中央銀行](https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html) を使用して、リアルタイムの為替を提供しています。

メッシュ内のサービスからこの外部 API へのすべての読み出しに3秒のタイムアウトを設定します。これを行うには、2つの Istio リソースが必要です。

最初に、ヨーロッパの中央銀行ホスト名 `ecb.europa.eu` をメッシュに論理的に追加する `ServiceEntry` です。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: currency-api
spec:
  hosts:
  - www.ecb.europa.eu
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
```

次に、API 呼び出しのタイムアウトを設定するための `VirtualService` トラフィックルールです。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: currency-timeout
spec:
  hosts:
    - www.ecb.europa.eu
  http:
  - timeout: 3s
    route:
      - destination:
          host: www.ecb.europa.eu
        weight: 100
```

通貨 API の ServiceEntry を作成すると、[Kiali service graph](https://istio.io/docs/tasks/telemetry/kiali/) に自動的に `ecb.europa.eu` が表示されます。（そしてすぐに**誰か**がそれを呼んでいるかを知ります）

![service graph](/images/ext-servicegraph.png)

また、この外部サービスのための [Grafana dashboard](https://istio.io/docs/tasks/telemetry/metrics/using-istio-dashboard/) も自動的に取得して、レスポンスコードやレイテンシなどのデータを表示します。

![grafana](/images/ext-grafana.png)

[Istio ドキュメント](https://istio.io/docs/tasks/traffic-management/egress/egress-control/#manage-traffic-to-external-services) を参照して、外部サービスの管理とセキュリティについて学びましょう。
