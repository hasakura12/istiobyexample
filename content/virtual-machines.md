---
title: "仮想マシン"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

Kubernetesでコンテナ化されたサービスを実行すると、自動スケーリング、依存関係の分離、リソースの最適化など、多くのメリットが得られます。 IstioをKubernetes環境に追加すると、多数のコンテナーを操作している場合でも、メトリクスの集計とポリシー管理を大幅に簡略化できます。

しかし、ステートフルサービス、またはレガシーアプリケーションが仮想マシンで実行されている場合はどうでしょうか。または、VMからコンテナーに移行する場合はどうでしょうか？心配要りません。仮想マシンをIstioサービスメッシュに統合できます。方法を見てみましょう。

![](/images/vm-call-flow.png)

この例では、地方図書館のWebアプリケーションを実行しています。このウェブアプリには複数のバックエンドがあり、すべてKubernetesクラスターで実行されています。 Kubernetesのワークロードの1つ、`inventory` は、PostgreSQLデータベースと通信し、図書館に追加された新しい本ごとにレコードを書き込みます。このデータベースは、別のクラウドリージョンの仮想マシンで実行されています。

VMベースのデータベースであるPostgreSQLの完全なIstioの機能を取得するには、VMにIstioサイドカープロキシをインストールし、クラスターで実行されているIstioコントロールプレーンと通信するように構成する必要があります。（これは外部の[ServiceEntries](/external-services)を追加するのとは異なる点に注意してください。）Postgresデータベースを3つのステップでメッシュに追加できます。[GitHubのデモコマンド](https://github.com/askmeegs/postgres-library/tree/0241acce9d7e2cede0de8ac9baa1338624f716eb#-postgres-library)に従ってください。

![](/images/vm-architecture.png)

1. **PodからVMへのトラフィック用の[ファイアウォールルールを作成](https://github.com/askmeegs/postgres-library#5-allow-pod-ip-traffic-to-the-vm)します。** これにより、Kubernetes PodのCIDR範囲からVMベースのワークロードに直接トラフィックを送信できます。
2. **VM上に[Istioをインストール](https://github.com/askmeegs/postgres-library#6-prepare-a-clusterenv-file-to-send-to-the-vm)します。** サービスアカウントキー、およびVMサービスが公開するポート（この場合は、PostgreSQLクライアントポート `5432`）をコピーします。 VMの `/etc/hosts` を更新して、クラスターで実行されているIstio IngressGatewayを介して `istio.pilot` および `istio.citadel` トラフィックをルーティングします。次に、VMにIstioサイドカープロキシとノードエージェントをインストールします。ノードエージェントは、相互TLS認証のために、サイドカープロキシにマウントするクライアント証明書を生成します。`systemctl` を使用してプロキシとノードエージェントを起動します。
3. **Kubernetesのワークロード[VMに登録](https://github.com/askmeegs/postgres-library#8-register-the-vm-with-istio-running-on-the-gke-cluster)します。** Postgresデータベースをメッシュに追加するには、2つのKubernetesリソースが必要です。 1つは `ServiceEntry`です。これにより、KubernetesのDNS名で仮想マシンのIPアドレスにルーティング可能になります。最後に、そのDNSエントリを作成するには、Kubernetesの `Service` が必要です。これにより、クライアントPodが `postgres-1-vm.default.svc.cluster.local` で[データベース接続を開始](https://github.com/askmeegs/postgres-library/blob/master/main.go#L39)できるようになります。これを行うには、`istioctl register` コマンドを使用できます。

Podのログを見ることで、Kubernetesベースのクライアントがデータベースに正常に書き込めることを確認できます。:

```
postgres-library-6bb956f86b-dt94x server ✅ inserted Fun Home
postgres-library-6bb956f86b-dt94x server ✅ inserted Infinite Jest
postgres-library-6bb956f86b-dt94x server ✅ inserted To the Lighthouse
```

また、VM上にあるEnvoyのアクセスログを見ることで、VM上で実行されているサイドカープロキシがポート `5432` で内向きのトラフィックを傍受していることを確認できます。

```
$ tail /var/log/istio/istio.log

[2019-11-14T19:09:00.174Z] "- - -" 0 - "-" "-" 268 441 194 - "-" "-" "-" "-"
"127.0.0.1:5432" inbound|5432|tcp|postgresql-1-vm.default.svc.cluster.local
127.0.0.1:54104 10.128.0.14:5432 10.24.2.23:40190
outbound_.5432_._.postgresql-1-vm.default.svc.cluster.local -
```

KialiサービスグラフでTCPメトリックフローを確認することもできます。:

![](/images/vm-kiali.png)

ここから、マルチ環境のサービスメッシュで、すべてのIstioトラフィックやセキュリティポリシーを使用できます。たとえば、メッシュ全体の相互TLSポリシーを追加することで、クラスターとVM間のすべてのトラフィックを暗号化できます。:

```YAML
apiVersion: "authentication.istio.io/v1alpha1"
kind: "MeshPolicy"
metadata:
  name: "default"
spec:
  peers:
  - mtls: {}
---
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```


より詳しく学ぶ:
- [ご自身の環境でこの例を動かしてみましょう](https://github.com/askmeegs/postgres-library)
- [別のサンプル例](https://github.com/GoogleCloudPlatform/istio-samples/tree/master/mesh-expansion-gce)
- [Istioのドキュメントをご覧ください](https://istio.io/docs/examples/virtual-machines/single-network/)