#!/usr/bin/env python3

from typing import List
from typing import Union
from ansible.module_utils._text import to_text


def do_format_map(txt: Union[str, List[str]], fmt: str) -> str:
    if not isinstance(txt, list):
        txt = [str(txt)]
    return to_text(fmt).format(*txt)


class FilterModule(object):
    def filters(self):
        return dict(format_map=do_format_map)
