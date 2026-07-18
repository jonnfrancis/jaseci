"""Shared client utilities."""

import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

def:pub cn(*inputs: any) -> any {
    return twMerge(clsx(inputs));
}

"""Format an ISO timestamp in the viewer's local timezone."""
def:pub format_datetime(value: str | None) -> str {
    if value is None { return "—"; }
    if value.strip() == "" { return "—"; }
    try {
        parsed = new(Date, value);
        if isNaN(parsed.getTime()) { return value; }
        return parsed.toLocaleString("en-US", {
            "year": "numeric", "month": "short", "day": "numeric",
            "hour": "numeric", "minute": "2-digit"
        }) as str;
    } except Exception { return value; }
}
