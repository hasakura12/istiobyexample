---
title: リトライロジック
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

マイクロサービスアーキテクチャは分散されています。これは、ネットワーク上のリクエストが増えることを意味し、ネットワークの輻輳などの一時的な障害の可能性が高まります。

リクエストにリトライポリシーを追加すると、サービスアーキテクチャの復元力を構築するのに役立ちます。多くの場合、このリトライロジックは[ソースコードに組み込まれて](https://upgear.io/blog/simple-golang-retry-function/)います。ただし、Istioでは、[トラフィックルール](https://istio.io/docs/concepts/traffic-management/#set-number-and-timeouts-for-retries)を使用してリトライポリシーを定義して、このロジックをサービスの[サイドカープロキシ](https://istio.io/docs/concepts/what-is-istio/#architecture)に任せることができます。これは、多くのサービス、プロトコル、およびプログラミング言語にわたって同じポリシーを中心に標準化するのに役立ちます。

![Diagram](/images/retry.png)

この例では、`helloworld` サービスへのすべての内向きのリクエストが5回試行され、完了までに2秒以上かかる場合、試行は失敗としてマークされます。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: helloworld
spec:
  host: helloworld
  subsets:
  - name: v1
    labels:
      version: v1
```

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: helloworld
spec:
  hosts:
  - helloworld
  http:
  - route:
    - destination:
        host: helloworld
        subset: v1
    retries:
      attempts: 5
      perTryTimeout: 2s
```