import logging
import json
from datetime import datetime
from pythonjsonlogger import jsonlogger
from backend.core.config import settings

class CustomJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record, record, message_dict):
        super().add_fields(log_record, record, message_dict)
        log_record['timestamp'] = datetime.utcnow().isoformat()
        log_record['level'] = record.levelname
        log_record['service'] = 'rct-engine'
        log_record['environment'] = settings.ENVIRONMENT

def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.INFO if not settings.DEBUG else logging.DEBUG)
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(CustomJsonFormatter())
    logger.addHandler(console_handler)
    
    # File handler for errors
    file_handler = logging.FileHandler('/var/log/rct_engine/error.log')
    file_handler.setLevel(logging.ERROR)
    file_handler.setFormatter(CustomJsonFormatter())
    logger.addHandler(file_handler)

def log_translation_event(org_id: str, word_count: int, risk_level: str, latency_ms: int):
    logging.info(json.dumps({
        "event_type": "translation",
        "organization_id": org_id,
        "word_count": word_count,
        "risk_level": risk_level,
        "latency_ms": latency_ms
    }))
