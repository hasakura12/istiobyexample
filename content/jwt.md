---
title: JWT
publishDate: "2019-12-31"
categories: ["Security"]
---

[JSON Web Token](https://jwt.io/introduction/)（JWT）は、サーバーアプリケーションでユーザーを識別するために使用される認証トークンの一種です。JWTにはクライアントの呼び出し元に関する情報が含まれており、クライアントセッションアーキテクチャの一部として使用できます。[JSON Web Key Set](https://auth0.com/docs/tokens/concepts/jwks)（JWKS）には、受信するJWTの検証に使用される暗号化キーが含まれています。

Istioの[認証API](https://istio.io/docs/reference/config/security/istio.authentication.v1alpha1/#Jwt)を使用して、サービスの[JWTポリシーを構成](https://istio.io/docs/concepts/security/#origin-authentication)できます。

![jwt](/images/jwt.png)

この例では、ホームページ（ `/` ）とPodヘルスチェック（ `/_healthz` ）を除いて、`frontend` サービスのすべてのルートにJWTが必要です。

Istioポリシーで、frontendのサイドカープロキシにマウントされるテスト公開鍵（ `jwksUri` ）へのパスを指定します。認証されていないリクエストはすべて、Envoyから `401-Unauthorized` ステータスを受け取ります。

```YAML
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "frontend-jwt"
spec:
  targets:
  - name: frontend
  origins:
  - jwt:
      issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.2/security/tools/jwt/samples/jwks.json"
      trigger_rules:
      - excluded_paths:
        - exact: /_healthz
        - exact: /
  principalBinding: USE_ORIGIN
```

詳細とインタラクティブな例を試すには、[Istio ドキュメント](https://istio.io/docs/tasks/security/authentication/authn-policy/#end-user-authentication)と[istio-samples リポジトリ](https://github.com/GoogleCloudPlatform/istio-samples/tree/master/security-intro#add-end-user-jwt-authentication)をご覧ください。