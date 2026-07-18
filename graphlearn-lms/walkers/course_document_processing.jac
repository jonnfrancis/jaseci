"""Private lecturer-facing document-processing status, retry, and cancellation walkers."""
import from lib.course_document.application_services { cancel_authorized_document_processing, get_authorized_document_processing_status, retry_authorized_document_processing }
import from nodes.curriculum { DocumentProcessingStatusView }

walker:priv get_course_document_processing_status { has track_id: str; has track_version_id: str; has document_id: str; has reports: list[DocumentProcessingStatusView] = []; can execute with Root entry { report get_authorized_document_processing_status(self.track_id, self.track_version_id, self.document_id); } }
walker:priv retry_course_document_processing { has track_id: str; has track_version_id: str; has document_id: str; has reports: list[DocumentProcessingStatusView] = []; can execute with Root entry { report retry_authorized_document_processing(self.track_id, self.track_version_id, self.document_id); } }
walker:priv cancel_course_document_processing { has track_id: str; has track_version_id: str; has document_id: str; has reason: str = "LECTURER_CANCELLED"; has reports: list[DocumentProcessingStatusView] = []; can execute with Root entry { report cancel_authorized_document_processing(self.track_id, self.track_version_id, self.document_id, self.reason); } }
