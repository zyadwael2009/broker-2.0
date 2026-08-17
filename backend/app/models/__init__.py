"""Model package. Importing this module registers all models with
SQLAlchemy metadata so Flask-Migrate can autogenerate migrations."""
from .user import User, UserRole
from .broker_profile import BrokerProfile, VerificationStatus
from .listing import Listing, PropertyType, ListingStatus, ListingKind, DeliveryStatus
from .listing_photo import ListingPhoto
from .listing_view import ListingViewDay
from .listing_document import ListingDocument, DocumentKind, DocumentState
from .message_thread import MessageThread
from .message import Message
from .broker_rating import BrokerRating
from .report import Report, ReportTargetType, ReportReason, ReportStatus
from .device_token import DeviceToken, DevicePlatform

__all__ = [
    "User",
    "UserRole",
    "BrokerProfile",
    "VerificationStatus",
    "Listing",
    "PropertyType",
    "ListingStatus",
    "ListingKind",
    "DeliveryStatus",
    "ListingPhoto",
    "ListingViewDay",
    "ListingDocument",
    "DocumentKind",
    "DocumentState",
    "MessageThread",
    "Message",
    "BrokerRating",
    "Report",
    "ReportTargetType",
    "ReportReason",
    "ReportStatus",
    "DeviceToken",
    "DevicePlatform",
]
