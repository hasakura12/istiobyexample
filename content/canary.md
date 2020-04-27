---
title: "カナリアデプロイメント"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---


カナリアデプロイメントは、新しいバージョンのサービスを安全に展開するための手法です。Istioを使うと、指定したパーセント指定で[トラフィック分割](https://istio.io/docs/concepts/traffic-management/#routing-versions)を行うことにより、新しいバージョンに対し，少量のトラフィックのみを流すことができます。その後、新しいバージョンに対し，[カナリア分析](https://cloud.google.com/blog/products/devops-sre/canary-analysis-lessons-learned-and-best-practices-from-google-and-waze)（レイテンシやエラー率のチェックなど）を実行しつつ、最終的に新しいバージョンが全てのトラフィックを受け付けるようになるまで、段階的にトラフィックを新しいバージョンに流していくことが可能です。

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
