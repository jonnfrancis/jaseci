"""Thin private course-document upload transport walker."""

import from lib.course_document.application_services { upload_authorized_course_document }
import from nodes.curriculum { CourseDocumentUploadResult, UploadCourseDocumentInput }

walker:priv upload_course_document {
    has input: UploadCourseDocumentInput;
    has reports: list[CourseDocumentUploadResult] = [];
    can execute with Root entry { report upload_authorized_course_document(self.input); }
}
