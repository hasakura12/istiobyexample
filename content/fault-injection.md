---
title: "フォールトインジェクション"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

マイクロサービスを採用すると、多くの場合、依存関係が増え、制御できないサービスが増えます。また、ネットワーク上のリクエストが増えるため、エラーが発生する可能性が高くなります。これらの理由により、アップストリームの依存関係が失敗したときのサービスにおける動作をテストすることが重要です。

**[カオステスト](https://en.wikipedia.org/wiki/Chaos_engineering)** は、弱点を明らかにし、フォールトトレランスを向上させるために、サービスを意図的に壊すプロセスです。カオステストでは、エラーを返す代わりに、クライアント側のバグを明らかにしたり、キャッシュされた結果を表示したいユーザー向けに障害状況を特定できます。

Kubernetes環境では、[Podをランダムに削除](https://github.com/asobti/kube-monkey#kube-monkey--)したり、ノード全体をシャットダウンしたりするなど、さまざまなレイヤーでのカオステストに取り組むことができます。

ただし、障害はアプリケーション層でも発生します。無限ループ、壊れたクライアントライブラリ-アプリケーションコードは無限に失敗する可能性があります！ここで Istio **[fault injection](https://istio.io/docs/concepts/traffic-management/#fault-injection)** の出番です。Istio VirtualServicesを使用して、実際にアプリのコードを更新せずに、タイムアウトまたはHTTPエラーをサービスに起こすことにより、アプリケーションレイヤーでカオステストを実行できます。方法を見てみましょう。

![](/images/fault-injection.png)


この例では、風力エネルギー会社が2つのKubernetesクラスターを実行しています。1つはクラウド内、もう1つはオフショアの風力発電所内です。これら2つのクラスターは、[単一のコントロールプレーンのmulticluster Istio](https://istio.io/docs/setup/install/multicluster/shared-gateways/)を使用して相互に接続されて、クラウドクラスターで実行されます（*注*-この例は、単一クラスターセットアップでも機能します）。 3つのサービスがあります。`ingest` は、タービンからのセンサーデータを処理し、オンプレミスの時系列データベースに書き込みます。`insights` はデータベースをポーリングして電源の異常を検出し、`alerts` にメッセージを送信し、クラウドで実行され、電力グリッドへの潜在的な脅威がある場合に実行します。

insights サービスが `alerts` のホームを呼び出せない場合、異常が失われないようにする必要があります。理想的には、insights がアラートをキャッシュするか、Istioの[リトライロジック](/retry)を使用してリクエストを再送信します。この障害シナリオで何が発生するかをテストするために、Istioを使用して `alerts` サービスに障害を起こします。最初に5秒の遅延を追加し、次に `500 - Internal Server Error` を追加します。:

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: alerts-fault
spec:
  hosts:
  - alerts
  http:
  - fault:
      abort:
        httpStatus: 500
        percentage:
          value: 100
      delay:
        percentage:
          value: 100
        fixedDelay: 5s
    route:
    - destination:
        host: alerts
```

このVirtualServiceを適用すると、`insights` アプリケーションコンテナーからの `alerts` を纏めることができ、構成されたタイムアウトに続いて500エラーが表示されます。:

```bash
$ curl -v alerts.default.svc.cluster.local:80/

...
* Connected to alerts.default.svc.cluster.local (10.12.10.16) port 80 (#0)

< HTTP/1.1 500 Internal Server Error
...
fault filter abort
```

そして、`insights` ログを調べて、クライアント側がその失敗をどのように処理したかを確認できます。

これらのフォールトインジェクションルールをカスタマイズできることに注意してください。たとえば、（VirtualServicesを追加することで）一度に複数のサービスを失敗させる、[リクエストの一部のみを失敗させる](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection-Abort)、または特定のHTTPリクエストヘッダー（ `user-agent` など）でのみ失敗して動作をテストする特定のウェブブラウザ）。
エンドツーエンドのカオステストプロセスを自動化するために、独自のカオステストラッパーを作成することもできます（フォールトインジェクションルールの追加、クライアントの動作/状態の検査）。これを行うには、[Istio Golangクライアントライブラリ](https://github.com/istio/client-go)を使用して、クラスター上でVirtualServicesをプログラム的にライフサイクルを回します。

ソース：

- [Istio Docs - タスク：フォールトインジェクション](https://istio.io/docs/tasks/traffic-management/fault-injection/)
- [Istio Docs - リファレンス：フォールトインジェクション](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection)
- [Delivering Renewable Energy with Kubernetes（Kubecon China 2018）](https://static.sched.com/hosted_files/kccncchina2018english/18/ShengLiang-En.pdf)