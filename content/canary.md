---
title: "カナリアデプロイメント"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---


カナリアデプロイメントは、新バージョンのサービスを安全に展開するための手法です。Istioを使うと、パーセント指定での[トラフィック分割](https://istio.io/docs/concepts/traffic-management/#routing-versions)により、少量のトラフィックのみ新バージョンのサービスに流すことが可能です。その後、[カナリア分析](https://cloud.google.com/blog/products/devops-sre/canary-analysis-lessons-learned-and-best-practices-from-google-and-waze)（レイテンシやエラー率のチェックなど）を実行しつつ、最終的に新バージョンのサービスが全てのトラフィックを受け付けるようになるまで、新バージョンのサービスへのトラフィックを段階的に増やしていくことが可能です。

![Diagram](/images/canary_diagram.png)

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
      weight: 90
    - destination:
        host: helloworld
        subset: v2
      weight: 10
```

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
  - name: v2
    labels:
      version: v2
```
