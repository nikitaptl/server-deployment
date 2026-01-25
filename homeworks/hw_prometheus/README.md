## Muffin Wallet — Prometheus

### Запуск

```bash
cd helm
kubectl apply -f monitoring-namespace.yaml
kubectl apply -f muffin-namespace.yaml
helmfile apply
```

---

### Проверка работоспособности

```bash
kubectl get pods -n muffin
kubectl get pods -n monitoring
```

Все pod’ы должны быть в состоянии `Running`.

---

### Нагрузочное тестирование

```bash
bash load.sh
```

---

### Просмотр метрик

Grafana:
```
https://grafana.muffin.nrunnercloud.xyz
```

Доступ:
```
username: guest
password: 23fasdfn39
```

Дашборд:
```
https://grafana.muffin.nrunnercloud.xyz/d/afba81ap52bk0c/muffin
```

После запуска нагрузочного скрипта на дашборде отображаются метрики и видно их изменение во времени.

---

## Примечания

- Prometheus развернут внутри кластера
- Метрики собираются напрямую с контейнеров приложения
- Доступ извне используется только для Grafana
