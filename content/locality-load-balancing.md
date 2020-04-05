---
title: ローカリティロードバランシング
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

大規模なグローバルアプリケーションを実行している場合、複数のリージョンでサービスを実行している可能性があります。同じサービスのレプリカが複数ある場合は、レイテンシを最小限に抑えるために、クライアントリクエストを最も近いサーバーに転送することができます。また、1つのリージョンがダウンした場合にフェイルオーバーを処理し、トラフィックを最も近い利用可能なサービスに転送する方法が必要になる場合もあります。

Istioは、**ローカリティロードバランシング**と呼ばれる機能を使用して、リージョンのトラフィックを自動的に処理してくれます。方法を見てみましょう。

![default](/images/loc-default.png)

ここでは、`us-central` と `us-east` の2つの異なるクラウドリージョンで実行されている2つのKubernetesクラスターがあります。 Istioコントロールプレーンは `us-east` で実行されており、両方のクラスターで実行されているサービスが互いに到達できるように、[単一のコントロールプレーン](https://github.com/GoogleCloudPlatform/istio-samples/tree/191859c03e73da7e98d451c967cefe24101d1933/multicluster-gke/single-control-plane#demo-multicluster-istio--single-control-plane)のIstioマルチクラスターをセットアップしました。

両方のクラスターを起動したときに、クラウドプロバイダーはリージョン固有の `failure-domain` をKubernetesノードに追加しました。:

```
failure-domain.beta.kubernetes.io/region: us-central1
failure-domain.beta.kubernetes.io/zone: us-central1-b
```

Istioはこれらのローカリティラベルをリクエストに付与して、Istioがリクエストを最も近い利用可能なリージョンにリダイレクトできるようにします。

両方のクラスターは、`echo` と呼ばれる Istio-injected サービスを実行しています。これは、ポート `80` でアクセスが来たときにその内容を返します。中央クラスターは、`echo.default.svc.cluster.local:80` を毎秒呼び出す `loadgen` サービスも実行しています。

デフォルトでは、Kubernetes Serviceの動作は、両クラスタの2つの `echo` サーバー間でのラウンドロビン方式です。:

```
$ 🌊 Hello World! - EAST
$ ✨ Hello World! - CENTRAL
$ 🌊 Hello World! - EAST
$ ✨ Hello World! - CENTRAL
```

`east` クラスタに [Outlier Detection](https://istio.io/docs/reference/config/networking/destination-rule/#OutlierDetection)定義を Istio DestinationRuleマニフェストファイルに追加することにより、ローカリティロードバランシングを有効にできます。:

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: echo-outlier-detection
spec:
  host: echo.default.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1000
      http:
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutiveErrors: 7
      interval: 30s
      baseEjectionTime: 30s
```

これで、すべての `loadgen` リクエストは、`us-central` で実行されている最も近い `echo` のインスタンスにルーティングされます。:

```
$ ✨ Hello World! - CENTRAL
$ ✨ Hello World! - CENTRAL
$ ✨ Hello World! - CENTRAL
```

![locality](/images/loc-locality.png)

`us-central` で実行されている `echo` デプロイメントを削除すると、Istioは `loadgen` リクエストを `us-east` で実行されている `echo` Podにリダイレクトします。:

```
$ 🌊 Hello World! - EAST
$ 🌊 Hello World! - EAST
$ 🌊 Hello World! - EAST
```

![failover](/images/loc-failover.png)

Istioのグローバルインストール設定で、メッシュ全体のトラフィックの割合に基づく負荷分散ルールを追加することもできます。:

```
    localityLbSetting:
      distribute:
      - from: us-central1/*
        to:
          us-central1/*: 20
          us-east1/*: 80
```

これで、両方のクラスターで実行されているすべてのサービスが、`us-east` と `us-central` の間でリクエストを80/20共有します。 VirtualServicesは必要ありません。

```
$ 🌊 Hello World! - EAST
$ 🌊 Hello World! - EAST
$ 🌊 Hello World! - EAST
$ 🌊 Hello World! - EAST
$ ✨ Hello World! - CENTRAL
```

![split](/images/loc-splittraffic.png)


Istioによるローカリティロードバランシングの詳細については、[Istio docs](https://istio.io/docs/ops/configuration/traffic-management/locality-load-balancing/)をご覧ください。