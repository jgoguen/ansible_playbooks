#!/usr/bin/env python3

import os
from ansible.module_utils._text import to_text


def direxist(path: str) -> str:
    if os.path.exists(path):
        return to_text(path)
    return to_text("")


class FilterModule(object):
    def filters(self):
        return dict(direxist=direxist)
