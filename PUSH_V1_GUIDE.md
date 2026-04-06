# Push V1 Guide

## Resume

Le service utilise maintenant une architecture push orientee production :

- FCM HTTP v1
- OAuth2 via service account Google
- cache de token d'acces backend
- fanout Oban par appareil
- retry/backoff
- tracking d'evenements et analytics

## Variables d'environnement

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `FCM_PROJECT_ID`
- `GOOGLE_APPLICATION_CREDENTIALS`
- ou `FCM_SERVICE_ACCOUNT_JSON`

## Tables

- `notifications`
- `user_notification_stats`
- `device_tokens`
- `notification_events`

## Events suivis

- `queued`
- `sent`
- `delivered`
- `opened`
- `clicked`
- `failed`
- `token_invalid`

## Flow

1. Flutter enregistre son token FCM via `POST /api/notifications/register-device`
2. Le backend stocke le token dans `device_tokens`
3. `POST /api/notifications` cree la notification
4. `NotificationFanoutWorker` pousse le temps reel
5. `NotificationPushFanoutWorker` planifie un job `NotificationWorker` par device actif
6. `NotificationWorker` appelle FCM v1
7. Les evenements sont stockes dans `notification_events`
8. Flutter renvoie `delivered`, `opened` ou `clicked`
9. `GET /api/notifications/:id/analytics` expose les KPI

## Payload exemple

```json
{
  "notification": {
    "user_id": "42",
    "type": "post",
    "title": "Nouveau contenu pour toi",
    "message": "Une universite que tu suis a publie un nouveau short",
    "priority": "high",
    "deep_link": "universearch://posts/abc123",
    "campaign_type": "engagement",
    "delivery_types": ["in_app", "push"],
    "data": {
      "post_id": "abc123",
      "author_id": "u-77"
    }
  }
}
```

## Broadcast / segmentation

```json
{
  "notification": {
    "targeting": {
      "user_type": "student",
      "platforms": ["android", "ios"],
      "interests": ["medecine", "informatique"]
    },
    "type": "sponsored",
    "title": "Bourse disponible",
    "message": "Une nouvelle opportunite correspond a ton profil",
    "campaign_type": "sponsored",
    "priority": "normal"
  }
}
```

## Tracking cote app

```json
POST /api/notifications/:id/events
{
  "event_type": "opened",
  "token": "<fcm_token>",
  "metadata": {
    "screen": "shorts",
    "source": "firebase_messaging.onMessageOpenedApp"
  }
}
```

## Notes production

- ne jamais committer le service account
- utiliser un secret manager
- faire tourner les cles
- proteger `POST /api/notifications` et `/broadcast` derriere une auth service-to-service
- brancher les dashboards sur `notification_events`
