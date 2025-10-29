# Muffin Wallet — локальное развертывание через Kubernetes (Kind)

## Запуск

Скрипт [`up.sh`](./up.sh) автоматически поднимает локальный кластер Kubernetes с помощью **Kind**  
и разворачивает приложение **Muffin Wallet** с PostgreSQL и HTTPS-доступом через **Ingress NGINX**.

Что делает `up.sh`:
1. Добавляет `muffin.local` в `/etc/hosts` и создаёт локальный SSL-сертификат через **mkcert**.
2. Создаёт кластер Kind с пробросом портов **80/443**.
3. Устанавливает **ingress-nginx** контроллер.
4. Применяет все Kubernetes-манифесты из папки [`k8s`](./k8s)  
   (namespace, configmap, secrets, postgres, deployment, service, ingress и др.).
5. Создаёт TLS Secret до применения Ingress.
6. Применяет Ingress с fallback-механизмом, чтобы избежать ошибок валидации вебхука.
7. Проверяет готовность подов и доступность сервиса по адресу:

[https://muffin.local](https://muffin.local)

После выполнения скрипта приложение доступно локально по HTTPS с «зелёным замком».

---

## Завершение работы

Скрипт [`down.sh`](./down.sh) полностью очищает окружение:
- удаляет namespace `muffin` и контроллер `ingress-nginx`;
- удаляет кластер Kind;
- при желании очищает `/etc/hosts` и локальные сертификаты.

---

## Структура

Все необходимые Kubernetes-манифесты находятся в директории [`k8s/`](./k8s):
