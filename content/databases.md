---
title: データベーストラフィック
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---


アプリケーションは複数の環境にまたがる場合が多く、データベースはその良い例です。レガシーまたはストレージの理由で、データベースを[Kubernetesの外](https://cloud.google.com/blog/products/databases/to-run-or-not-to-run-a-database-on-kubernetes-what-to-consider)で実行することを選択するか、マネージドデータベースサービスを使用することができます。

しかし心配は要りません！ Istioサービスメッシュに外部データベースを追加できます。方法を見てみましょう。

![diagram](/images/databases-diagram.png)

ここでは、Istioが有効になっているKubernetesクラスター内で実行されている `plants` サービスがあります。`plants` は、[Firestore](https://firebase.google.com/docs/firestore)用のGolangクライアントライブラリを使用して、Google Cloudで実行されているFirestore NoSQLデータベースにインベントリを書き込みます。ログは次のようになります。:

```bash
writing a new plant to Firestore...
✅success
```

Firestoreへの送信トラフィックを監視するとします。これを行うには、[Firestore API](https://cloud.google.com/firestore/docs/reference/rpc/)のホスト名に対応するIstio [ServiceEntry](https://istio.io/docs/reference/config/networking/service-entry/)を追加します。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: firestore
spec:
  hosts:
  - "firestore.googleapis.com"
  ports:
  - name: https
    number: 443
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

ここから、Istioの[サービスグラフ](https://istio.io/docs/tasks/observability/kiali/)にFirestoreが表示されます。

![kiali](/images/databases-kiali-no-vs.png)

`plants` のサイドカープロキシがFirestore TLSトラフィックを [plain TCPとして](https://github.com/istio/istio/issues/14933)受信しているため、トラフィックはTCPとして表示されることに注意してください。グラフの先頭は、Firestoreへのリクエストスループットの数をビット/秒で示しています。

ここで、データベースに接続できない場合の `plants` の動作をテストするとします。アプリケーションコードを変更せずに、Istioで行えます。

Istioは現在TCPフォールトインジェクションをサポートしていませんが、Firestore APIトラフィックを別の「ブラックホール」サービスに送信する[TCPトラフィックルール](https://istio.io/docs/reference/config/networking/virtual-service/#TCPRoute)を作成して、Firestoreへのクライアント接続を効果的に切断することができます。

これを行うには、クラスター内に小さな `echo` サービスをデプロイして、代わりにすべてのFirestoreトラフィックを `echo` サービスに転送します。:

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: fs
spec:
  hosts:
  - firestore.googleapis.com
  tcp:
  - route:
    - destination:
        host: echo
        port:
          number: 80
```

このIstio VirtualServiceをクラスターに適用すると、`plants` ログにエラーが報告されます。:


```bash
writing a new plant to Firestore...
🚫 Failed adding plant: rpc error: code = Unavailable desc = all SubConns are in TransientFailure
```

そして、サービスグラフでは、`firestore` ノードに紫色の `VirtualService` アイコンがあることがわかります。これは、そのサービスに対してIstioトラフィックルールを適用したことを意味します。最終的に、すべての送信接続をデータベースにリダイレクトしたため、firestoreへのスループットは最後の1分間は `0` と表示されます。

![kiali](/images/databases-kiali.png)

Istioで、Redis、SQL、[MongoDB](https://istio.io/blog/2018/egress-mongo/)など、クラスター内のデータベースのトラフィックを管理することもできます。詳細については、Istio docsをご覧ください。