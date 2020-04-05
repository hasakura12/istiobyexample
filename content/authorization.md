---
title: "認可"
publishDate: "2019-12-31"
categories: ["Security"]
---

認証とは、クライアントの身元を確認することです。一方、**認可**では、そのクライアントのアクセス権限を確認します。すなわち、「このサービスは、クライアントの要求を実行可能かどうか？」を確認します。

Istioメッシュのすべてのリクエストはデフォルトで許可されていますが、ワークロードのきめ細かなポリシーを定義できる[`AuthorizationPolicy` resource](https://istio.io/docs/reference/config/security/authorization-policy/)を[Istioは提供](https://istio.io/docs/concepts/security/#authorization)します。 IstioはAuthorizationPoliciesをEnvoyで読み取り可能な構成に変換し、その構成をIstioサイドカープロキシにマウントします。そこから、認可ポリシーチェックがサイドカープロキシによって実行されます。それがどのように機能するか見てみましょう。

![shoes rbac](/images/rbac.png)

ここでは、ShoeStoreアプリケーションが Kubernetesの `default` Namespaceにデプロイされています。3つのHTTPワークロードがあり、それぞれ独自のKubernetes Deployment、Service、ServiceAccountで定義されています。

1. **shoes**：ストア内のすべての靴のAPIを公開
2. **users**：ストアの購入履歴
3. **inventory**：新しい靴モデルをshoesにロードします。

inventoryサービスがshoesサービス にデータを `POST` できるように認可し、usersサービスへのすべてのアクセスをロックします。これを行うには、`shoes` 用と `users` 用の2つの `AuthorizationPolicies` を作成します。

ポリシーをデプロイする前は、inventoryサービスのアプリケーションコンテナー内からshoesとusersの両方にアクセスできます。

```bash
$ curl -X GET shoes
🥾 Shoes service
```

```bash
$ curl -x GET users
👥 Users service
```

まず、`shoes` 用のAuthorizationPolicyを作成します。：

```YAML
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "shoes-writer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: shoes
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/inventory-sa"]
    to:
    - operation:
        methods: ["POST"]
```

このポリシーでは：

- `shoes` の `selector` は、`app：shoes` というラベルの付いたDeploymentに適用されることを意味します。
- 私たちが許可している `source` ワークロードには、`inventory-sa` IDがあります。これは、Kubernetes環境では、`inventory-sa` [サービスアカウント](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)を持つPodのみがshoesにアクセスできることを意味します。（**注**：サービスアカウントベースの認可ポリシーを使用するには、[Istio相互TLS認証](https://istio.io/docs/tasks/security/authentication/authn-policy/#globally-enabling-istio-mutual-tls)を有効にする必要があります。相互TLSにより、ワークロードの[サービスアカウント](https://istio.io/docs/concepts/security/#istio-security-vs-spiffe)証明書をリクエストで渡すことができます。）
- ホワイトリストに登録されている唯一のHTTP操作は `POST` です。つまり、`GET` などの他のHTTP操作は拒否されます。

`shoes-writer` のポリシーを適用したら、inventoryから `POST` することができます。

```
$ curl -X POST shoes
🥾 Shoes service
```

ただし、`inventory` からの `GET` リクエストは拒否されます。:

```
$ curl -X GET shoes
RBAC: access denied
```

また、`users` など、`inventory` 以外のワークロードから `POST` しようとすると、リクエストが拒否されます。:

```
$ curl -X POST shoes
RBAC: access denied
```

次に、usersサービスの「deny-all」ポリシーを作成します。：

```YAML
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "users-deny-all"
  namespace: default
spec:
  selector:
    matchLabels:
      app: users
```

このサービスには `rules` がないことに注意してください。users Deploymentの `matchLabels` のみです。また、deny-allとallow-all AuthorizationPolicyの[違い](https://istio.io/docs/concepts/security/#allow-all-and-deny-all)はわずかであることに注意してください。allow-allポリシーでは、`rules: {}` を指定します。

このリソースを適用すると、どのサービスからもusersにアクセスできなくなります。：

```
$ curl users
RBAC: access denied
```

詳しく学ぶ:

- [この例のマニフェストファイル](https://github.com/askmeegs/istiobyexample/tree/master/yaml/authorization)
- [Istio ブログ - Istio v1beta1認可ポリシーの紹介](https://istio.io/blog/2019/v1beta1-authorization-policy/)
- [Istio docs - 認可の概念](https://istio.io/docs/concepts/security/#authorization)
- [Istio docs - 認可タスク](https://istio.io/docs/tasks/security/authorization/authz-http/)
- [Istio サンプル - Istioセキュリティの概要](https://github.com/GoogleCloudPlatform/istio-samples/tree/6fa69cf46424c055535ddbdc22f715e866c4d179/security-intro#demo-introduction-to-istio-security)
