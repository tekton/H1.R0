from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class ExifDatum(Base):
    __tablename__ = "exif_data"

    id = Column(Integer, primary_key=True, index=True)
    parent = Column(Integer, nullable=True)
    image_id = Column(Integer, ForeignKey("images.id"), nullable=True)
    tag = Column(String)
    value = Column(String)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    image = relationship("Image", back_populates="exif_data")
