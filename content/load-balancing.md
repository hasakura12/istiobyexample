---
title: 負荷分散
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

Kubernetesは、[内向けの](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)トラフィックの負荷分散をサポートしています。しかし、クラスター内のKubernetes Serviceについてはどうでしょうか？

クラスター内サービスが[通信](https://kubernetes.io/docs/concepts/services-networking/#proxy-mode-iptables)するとき、kube-proxyと呼ばれるロードバランサーがリクエストをService Podにランダムに[転送](https://cloud.google.com/kubernetes-engine/docs/concepts/network-overview#services)します。 Istioを使用することで、Envoyを有効化して、より複雑な負荷分散方式を追加できます。

Envoyは、[ランダム](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/load_balancers#random)、[ラウンドロビン](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/load_balancers#weighted-round-robin)、[最小リクエスト](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/load_balancers#weighted-least-request)など、複数の負荷分散方式をサポートしています。

Istioを使用して、Web `frontend` のすべてのトランザクションを処理する、`payments`と呼ばれるサービスの**最小リクエスト**負荷分散方式を追加する方法を見てみましょう。paymentsサービスは3つのPodによって支えられています。

この最小リクエストアルゴリズムでは、クライアント側のEnvoyは最初にランダムに2つのインスタンスを選択します。次に、アクティブなリクエストの数が最も少ないインスタンスにリクエストを転送し、すべてのインスタンス間で負荷を均等に分散できるようにします。

![load balancing](/images/lb-least-requests.png)

この機能を有効にするには、マニフェストファイルで、trafficPolicyのloadBalancerに [`LEAST_CONN`](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#LoadBalancerSettings-SimpleLB) を設定して、Istio [DestinationRule](https://istio.io/docs/reference/config/networking/destination-rule/)を作成します。:

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: payments-load-balancer
spec:
  host: payments.prod.svc.cluster.local
  trafficPolicy:
      loadBalancer:
        simple: LEAST_CONN
```

[Istio docs](https://istio.io/docs/concepts/traffic-management/#load-balancing-3-subsets)を参照して、単一のホストに複数の負荷分散方式を追加する方法を確認してください。