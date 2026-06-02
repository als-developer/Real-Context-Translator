from celery import Celery
from backend.core.config import settings

celery_app = Celery(
    "rct_engine",
    broker=settings.REDIS_URL,
    backend=f"{settings.REDIS_URL}/0"
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,
    task_soft_time_limit=25 * 60,
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=100,
)

celery_app.conf.beat_schedule = {
    "generate-daily-report": {
        "task": "backend.workers.report_generator.generate_daily_report",
        "schedule": 86400.0,  # Once per day
    },
    "cleanup-old-logs": {
        "task": "backend.workers.report_generator.cleanup_old_logs",
        "schedule": 3600.0,  # Every hour
    },
    "sync-billing-usage": {
        "task": "backend.workers.batch_translate.sync_usage_to_stripe",
        "schedule": 300.0,  # Every 5 minutes
    }
}

@celery_app.task(bind=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
