from sqlalchemy import Column, Integer, String, DateTime, Text, Index
from sqlalchemy.sql import func
from app.database import Base


class Search(Base):
    __tablename__ = "searches"

    id = Column(Integer, primary_key=True, index=True)
    md5hash = Column(String, unique=True, index=True)
    serial = Column(Text)   # stored as JSON string
    new_tag = Column(String, nullable=True)
    new_val = Column(String, nullable=True)
    left = Column(String, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
