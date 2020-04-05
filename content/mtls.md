---
title: "相互TLS"
publishDate: "2019-12-31"
categories: ["Security"]
---

マイクロサービスアーキテクチャは、ネットワーク上のリクエストが増えることと、悪意のある当事者がトラフィックを傍受する機会が増えることを意味します。[相互TLS](https://en.wikipedia.org/wiki/Mutual_authentication)（mTLS）認証は、[証明書](https://www.internetsociety.org/deploy360/tls/basics/)を使用してサービストラフィックを暗号化する方法です。

Istioを使用すると、すべてのサービスにわたるmTLSの適用を自動化できます。以下では、メッシュ全体に対してmTLSを有効にします。クラスター内の2つのPod（ `クライアント` と `サーバー` ）は、mTLSポリシーを使用してセキュアな接続を確立しているところを示しています。

![Diagram](/images/mtls.png)


```YAML
apiVersion: authentication.istio.io/v1alpha1
kind: MeshPolicy
metadata:
  name: default
spec:
  peers:
  - mtls:
      mode: STRICT
```

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: default
  namespace: istio-system
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

ここでは、`MeshPolicy` はリクエストを受信するすべてのサービス（サーバー側）にTLSを適用し、`DestinationRule` はリクエストを送信するすべてのサービス（クライアント側）にTLSを適用し、相互（「両方」）のTLSを作成します。

**認証フロー：**

1. `クライアント` アプリケーションコンテナーはプレーンテキストのHTTPリクエストを `サーバー` に送信します。
2. `クライアント` プロキシコンテナーが外向けのリクエストを傍受します。
3. `クライアント` プロキシは、サーバー側プロキシとTLS[ハンドシェイク](https://www.ibm.com/support/knowledgecenter/en/SSFKSJ_7.1.0/com.ibm.mq.doc/sy10660_.htm)を実行します。このハンドシェイクには、証明書の交換が含まれます。これらの証明書は、Istioによってプロキシコンテナーにプリロードされます。
4. `クライアント` プロキシは、サーバーの証明書に対して[セキュアな名前付け](https://istio.io/docs/concepts/security/#secure-naming)チェックを実行し、承認されたIDが `サーバー` を実行していることを確認します。
5. `クライアント` と `サーバー` は相互TLS接続を確立し、 `サーバー` プロキシはリクエストを `サーバー` アプリケーションコンテナーに転送します。

**詳しく学ぶ**：

- [Istio Docs - 認証](https://istio.io/docs/concepts/security/#authentication)
- [サンプル: 認証](https://github.com/GoogleCloudPlatform/istio-samples/tree/77fb1dfb690d28517e410df2911e255d54e3450e/security-intro#authentication)
- [タスク - 認証ポリシー](https://istio.io/docs/tasks/security/authentication/authn-policy/)
- [タスク - 相互TLS Deep-Dive](https://istio.io/pt-br/docs/tasks/security/authentication/mutual-tls/)
- [FAQ - mTLS](https://istio.io/faq/security/#enabling-disabling-mtls)