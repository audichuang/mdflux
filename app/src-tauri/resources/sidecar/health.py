"""Health-check: probes Python version, markitdown core, and each format extra.

The EXTRAS map is derived from capabilities._CORE_FORMATS so the two cannot drift
(see the Stage 3 review: health had an 'outlook' entry that capabilities didn't).
"""
import sys
import importlib.util

import capabilities as _caps


def _extras_map() -> dict[str, str]:
    return {
        f["key"]: f["module"]
        for f in _caps._CORE_FORMATS
        if f.get("module")
    }


def check() -> dict:
    result = {
        "python_version": sys.version.split()[0],
        "markitdown_version": None,
        "extras": {},
    }

    try:
        import importlib.metadata as md
        result["markitdown_version"] = md.version("markitdown")
    except Exception:
        try:
            import markitdown
            result["markitdown_version"] = getattr(markitdown, "__version__", "installed")
        except ImportError:
            pass

    for name, module in _extras_map().items():
        try:
            # Use find_spec to verify presence without importing the module
            installed = importlib.util.find_spec(module) is not None
            result["extras"][name] = installed
        except Exception:
            result["extras"][name] = False

    return result

