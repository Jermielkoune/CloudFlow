#!/usr/bin/env python3
"""
Convert Dependency-Check JSON report to SARIF 2.1.0
Usage: python3 depcheck_json_to_sarif.py <input_json> <output_sarif>
"""
from __future__ import annotations
import json
import sys
from typing import Any, Dict, List, Iterator, Tuple


def _iter_vulnerabilities(data: Dict[str, Any]) -> Iterator[Tuple[str, Dict[str, Any]]]:
    """Yield (file_uri, vulnerability) pairs from Dependency-Check JSON structure."""
    for dep in (data.get("dependencies") or []):
        file_uri = dep.get("fileName") or dep.get("filePath") or "unknown"
        for vuln in (dep.get("vulnerabilities") or []):
            yield file_uri, vuln


def _parse_score(raw_score: Any, raw_v3_base: Any) -> float:
    """Parse CVSS score from either raw_score or v3 base score, defaulting to 0.0."""
    candidate = raw_score
    if candidate in (None, ""):
        candidate = raw_v3_base
    if candidate in (None, ""):
        candidate = 0
    try:
        return float(candidate)
    except Exception:
        return 0.0


def _normalize_vuln(vuln: Dict[str, Any]) -> Tuple[str, str, float, str, str]:
    """Return (rule_id, severity, score, description, url) from a vulnerability dict."""
    rule_id = vuln.get("name") or vuln.get("id") or "UNKNOWN"
    sev = (vuln.get("severity") or "").upper()
    score = _parse_score(vuln.get("cvssScore"), (vuln.get("cvssv3", {}) or {}).get("baseScore"))
    desc = vuln.get("description") or ""
    url = vuln.get("url") or ""
    return rule_id, sev, score, desc, url


def _ensure_rule(rules: Dict[str, Dict[str, Any]], rule_id: str, sev: str, score: float, desc: str, url: str) -> None:
    """Ensure a SARIF rule exists for rule_id in rules map."""
    if rule_id in rules:
        return
    rules[rule_id] = {
        "id": rule_id,
        "name": rule_id,
        "shortDescription": {"text": str(rule_id)},
        "fullDescription": {"text": str(desc)[:2000]},
        "helpUri": url or None,
        "properties": {"problem.severity": sev, "security-severity": str(score)},
    }


def _make_result(rule_id: str, sev: str, score: float, desc: str, file_uri: str) -> Dict[str, Any]:
    """Create a SARIF result entry for a vulnerability occurrence."""
    return {
        "ruleId": rule_id,
        "level": ("error" if score >= 7.0 else "warning"),
        "message": {"text": f"{rule_id} ({sev}) score={score}: {str(desc)[:300]}"},
        "locations": [
            {"physicalLocation": {"artifactLocation": {"uri": file_uri}}}
        ],
    }


def to_sarif(input_path: str, output_path: str) -> None:
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    results: List[Dict[str, Any]] = []
    rules: Dict[str, Dict[str, Any]] = {}

    for file_uri, vuln in _iter_vulnerabilities(data):
        rule_id, sev, score, desc, url = _normalize_vuln(vuln)
        _ensure_rule(rules, rule_id, sev, score, desc, url)
        results.append(_make_result(rule_id, sev, score, desc, file_uri))

    sarif = {
        "version": "2.1.0",
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "OWASP Dependency-Check",
                        "informationUri": "https://owasp.org/www-project-dependency-check/",
                        "rules": list(rules.values()),
                    }
                },
                "results": results,
            }
        ],
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(sarif, f, indent=2)


def main(argv: List[str]) -> int:
    if len(argv) != 3:
        print("Usage: depcheck_json_to_sarif.py <input_json> <output_sarif>", file=sys.stderr)
        return 2
    to_sarif(argv[1], argv[2])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
