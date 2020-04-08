---
title: "複数のトラフィックルール"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

Istioは、[リダイレクト](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPRewrite)や[トラフィック分割](https://istio.io/docs/tasks/traffic-management/traffic-shifting/)から[ミラーリング](https://istio.io/docs/tasks/traffic-management/mirroring/)や[リトライロジック](https://istio.io/docs/concepts/traffic-management/#retries)まで、さまざまな[トラフィック管理](https://istio.io/docs/concepts/traffic-management/)の使用例をサポートしています。 Istio [VirtualService](https://istio.io/docs/reference/config/networking/virtual-service/)を作成して、サービスのためにこれらのポリシーの1つを定義した場合、同じリソースにさらにトラフィック管理ルールを追加するのは簡単です。この例は、1つのKubernetesベースのサービスに複数のトラフィックルールを適用する方法を示しています。

たとえば、新聞社のWebサイトの**frontend**エンジニアリングチームにいるとします。ユーザー向けのfrontendサービスは、**articles**というバックエンドに依存しており、articlesのコンテンツとメタデータをJSONとして提供します。しかし、articlesチームはサービスを新しい言語でリファクタリングしており、新しい変更を頻繁に展開しています。これにより，古いarticleサービスの挙動に依存しているfrontendでは予期せぬエラーが発生するようになりました。さらに複雑なことに、以前は別の**blog**サービスで提供されていた新聞のブログが、articlesサービスに組み込まれてしまいました。現在、すべてのブログ投稿は  `/beta/blog` パスで提供される記事です。

frontendに代わって articlesの動作を固定するために、articlesのIstioトラフィックポリシーを作成します。articlesに対するfrontendのトラフィック要件には、`/breaking-news` 記事に `no-cache` ヘッダーを付与する、`/blog` を `/beta/blog` に書き換える、すべてのリクエストで2秒のタイムアウトを適用するなどがあります。

![](/images/multiple-functionality.png)

この集約機能を取得するために、`/breaking-news` の[レスポンスヘッダの変更](/response-headers)、`/blog` のURL書き換え、およびarticlesサービスへのデフォルトのフォールスルーの3つの `http` ルールを使用して、articlesに対して1つのVirtualServiceを作成します。 3つのルールすべてに2秒のタイムアウトがあります。

![](/images/multiple-vs.png)


```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: articles-vs
spec:
  hosts:
  - articles
  http:
  - match: # RULE 1 - BREAKING NEWS
    - uri:
        prefix: "/article/breaking-news"
    route:
    - destination:
        host: articles
      headers:
        response:
          add:
            no-cache: "true"
      timeout: 2s
  - match: # RULE 2 - BLOG URI REWRITE
    - uri:
        prefix: /blog
    rewrite:
      uri: /beta/blog
    route:
    - destination:
        host: articles
      timeout: 2s
  - route: # RULE 3 / DEFAULT - TIMEOUT
    - destination:
        host: articles
    timeout: 2s
    weight: 100
```

このVirtualServiceをクラスターに適用した後、 kubectl exec で frontend Pod に入り，articles サービスにアクセスすると、ルールが有効になっていることを確認できます。たとえば、`/breaking-news` 記事をリクエストすると、応答に `no-cache:true` ヘッダーが追加されます。:

```bash
$ curl -v http://articles:80/article/breaking-news/2020/astrophysics-discovery

< HTTP/1.1 200 OK
< date: Wed, 15 Jan 2020 22:10:52 GMT
...
< no-cache: true
```

`/blog` で始まるパスをリクエストすると、`/beta/blog` に書き直され、articlesは `/beta/blog` パスを提供することが分かります。

```bash
$ curl http://articles:80/blog/2020/new-engineering-blog

{"id":91385,"title":"Welcome to the new News Blog!" ...
```

最後に、articlesサービスのアプリケーションコードに10秒のスリープ処理を追加すると、2秒のタイムアウトの動作を確認できます。:

```bash
$ curl  http://articles:80/

upstream request timeout
```

![](/images/multiple-fault.png)

**注**：1つのVirtualServiceに複数のルールを追加すると、上から下まで**順番に**[ルールは評価](https://istio.io/docs/concepts/traffic-management/#routing-rule-precedence)されます。したがって、articlesのVirtualServiceへ，全てのリクエストにHTTPステータスコード `404: Not Found` を返すような[fault injection](https://istio.io/docs/tasks/traffic-management/fault-injection/#injecting-an-http-abort-fault…)ルールを追加した場合、そのルールは他の3つをオーバーライドし、Articlesサービス全体を停止します。:

```bash
curl -v http://articles:80
...
* Connected to articles (10.0.21.31) port 80

< HTTP/1.1 404 Not Found
```

VirtualServicesにはこのルールの優先順位があるため、複雑なIstioトラフィックポリシーを検証およびテストすることが重要です。上記で行ったように、「フォールスルー」またはデフォルトのルールを追加して、特定のホストに対するすべてのリクエストが確実にルーティングされるようにすることもお勧めします。