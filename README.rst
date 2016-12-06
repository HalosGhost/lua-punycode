punycode
========

Punycode is an encoding for arbitrary Unicode into 7-bit clean ASCII.

It was specified by the IETF in `RFC 3492 <https://tools.ietf.org/html/rfc3492>`_ for use with IDNs and IDNA.
This module provides encoding and decoding procedures for punycode, *not* IDNA.

Only a few extra steps would need to be taken to support IDNA (namely, to fail out if a string contains only ASCII characters and to handle ``xn--`` preficies); however, this module is meant to be more general-purpose.

Only two functions will be exposed on import: ``encode`` and ``decode``, both take only one argument of type ``string`` and return one value also of type ``string``.

This module targets lua 5.x and luajit.
