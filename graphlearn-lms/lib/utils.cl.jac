"""Shared client utilities."""

import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

def:pub cn(*inputs: any) -> any {
    return twMerge(clsx(inputs));
}
