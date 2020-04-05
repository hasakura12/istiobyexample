---
title: "トラフィックミラーリング"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

信頼性を確保するには、本番環境でサービスをテストすることが重要です。稼働中の本番トラフィックをサービスの新しいバージョンに送信すると、継続的な統合と機能テスト中にテストされなかったバグを明らかにできます。

Istioを使用すると、[**トラフィックミラーリング**](https://istio.io/docs/tasks/traffic-management/mirroring/)を使用して、別のサービスへのトラフィックを複製できます。[カナリアデプロイメント](https://istiobyexample.dev/canary)パイプラインの一部としてトラフィックミラーリングルールを組み込むことができます。これにより、ライブトラフィックをサービスに送信する前にサービスの動作を分析できます。

この例では、Kubernetesにビデオ処理パイプラインをデプロイしました。`render` サービスは `encode-prod` サービスに依存しており、`encode`、 `encode-test` の新しいバージョンをロールアウトしたいと思います。

![traffic mirroring](/images/traffic-mirror.png)

Istio `VirtualService` を使用して、すべての`encode-prod`トラフィックを `encode-test` にミラーリングできます。`render` 用のクライアント側のEnvoyプロキシは、`encode-prod`（リクエストパス）と`encode-test`（ミラーリングパス）の両方にリクエストを送信します。 `prod` と `test` は、Istio `DestinationRule`で指定されている `encode` Kubernetes Serviceの2つのサブセットです。

**注**：`render`は、`encode-test`からの応答の受信を[待機しません](https://www.envoyproxy.io/docs/envoy/latest/api-v2/api/v2/route/route.proto#route-routeaction-requestmirrorpolicy) —ミラーリングされたリクエストは「実行して忘れる」ことになります。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: encode-mirror
spec:
  hosts:
    - encode
  http:
  - route:
    - destination:
        host: encode
        subset: prod
      weight: 100
    mirror:
      host: encode
      subset: test
```

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: encode
spec:
  host: encode
  subsets:
  - name: prod
    labels:
      version: prod
  - name: test
    labels:
      version: test
```