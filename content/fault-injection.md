---
title: "フォールトインジェクション"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

マイクロサービスを採用すると、多くの場合、依存関係が増え、制御できないサービスが増えます。また、ネットワーク上のリクエストが増えるため、エラーが発生する可能性が高くなります。これらの理由により、アップストリームの依存関係が失敗したときのサービスにおける動作をテストすることが重要です。

**[カオステスト](https://en.wikipedia.org/wiki/Chaos_engineering)** は、弱点を明らかにし、フォールトトレランスを向上させるために、サービスを意図的に壊すプロセスです。カオステストでは、エラーを返す代わりに、クライアント側のバグを明らかにしたり、エラーを返すのではなくキャッシュされた結果を表示したいと思うようなユーザーが直面する問題の状況を特定したりすることができます。

Kubernetes環境では、[Podをランダムに削除](https://github.com/asobti/kube-monkey#kube-monkey--)したり、ノード全体をシャットダウンしたりするなど、さまざまなレイヤーでのカオステストに取り組むことができます。

ただし、障害はアプリケーション層でも発生します。無限ループ、壊れたクライアントライブラリ-アプリケーションコードは無限に失敗する可能性があります！ここで Istio **[fault injection](https://istio.io/docs/concepts/traffic-management/#fault-injection)** の出番です。Istio VirtualServicesを使用して、実際にアプリのコードを更新せずに、タイムアウトまたはHTTPエラーをサービスに起こすことにより、アプリケーションレイヤーでカオステストを実行できます。方法を見てみましょう。

![](/images/fault-injection.png)


この例では、風力エネルギー会社が2つのKubernetesクラスターを実行しています。1つはクラウド内、もう1つはオフショアの風力発電所内です。これら2つのクラスターは、[単一のコントロールプレーンのマルチクラスタ構成のIstio](https://istio.io/docs/setup/install/multicluster/shared-gateways/)を使用して相互に接続されて、クラウド側クラスターで実行されます（*注*-この例は、単一クラスターセットアップでも機能します）。 3つのサービスがあります。`ingest` は、タービンからのセンサーデータを処理し、オンプレミスの時系列データベースに書き込みます。`insights` は発電機の異常検出のためにデータベースをポーリングし，電力系統への潜在的な驚異がある場合，クラウドで稼働する `alerts` にメッセージを送信します。

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

このVirtualServiceを適用し、`insights` アプリケーションコンテナーから `alerts` に curl でアクセスすると、構成されたタイムアウトに続いて500エラーが表示されます。:

```bash
$ curl -v alerts.default.svc.cluster.local:80/

...
* Connected to alerts.default.svc.cluster.local (10.12.10.16) port 80 (#0)

< HTTP/1.1 500 Internal Server Error
...
fault filter abort
```

そして、`insights` ログを調べて、クライアント側がその失敗をどのように処理したかを確認できます。

これらのフォールトインジェクションルールをカスタマイズできることに注意してください。たとえば、（VirtualServicesを追加することで）一度に複数のサービスを失敗させる、[指定した割合のリクエストのみを失敗させる](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection-Abort)、または特定のHTTPリクエストヘッダー（特定のWebブラウザーの挙動をテストするための `user-agent` など）のみ失敗させることなどが可能です。
エンドツーエンドのカオステストプロセスを自動化するために、独自のカオステストラッパーを作成することもできます（フォールトインジェクションルールの追加、クライアントの動作/状態の検査）。これを行うには、[Istio Golangクライアントライブラリ](https://github.com/istio/client-go)を使用して、クラスター上のVirtualServicesに対し，プログラム的なライフサイクルを回すことができます。

ソース：

- [Istio Docs - タスク：フォールトインジェクション](https://istio.io/docs/tasks/traffic-management/fault-injection/)
- [Istio Docs - リファレンス：フォールトインジェクション](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPFaultInjection)
- [Delivering Renewable Energy with Kubernetes（Kubecon China 2018）](https://static.sched.com/hosted_files/kccncchina2018english/18/ShengLiang-En.pdf)