## Muffin Wallet — Logging and Tracing

Запуск

```bash
minikube start
```

```bash
cd helm
helmfile apply
```

```bash
sudo minikube tunnel
echo -e "127.0.0.1 muffin.test\n127.0.0.1 grafana.muffin.test" | sudo tee -a /etc/hosts > /dev/null
```