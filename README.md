Railroad Control System Delphi Interface
========================================

This repository contains delphi interface to Railroad Control System libraries,
e.g. [MTB library](https://github.com/kmzbrnoI/mtb-lib) or
[Simulator library](https://github.com/kmzbrnoI/mtb-simulator-lib).

It allows programmer to use these libraries and to dynamically switch between
them. It provides simple event-based interface via `TRCSIFace` class defined
in `RCS.pas`.

It is intended for projects benefiting from possibility of changing the library
on-line, e. g. [hJOPserver](https://github.com/kmzbrnoI/hJOPserver).

This interface was originally created by Michal Petrilak as *OutputDriver*
project.

Interface between dlls and this interface is described at
[MTB wiki](https://github.com/kmzbrnoI/mtb-lib/wiki).

## Authors
 - Jan Horacek (jan.horacek@kmz-brno.cz) (current maintainer)
 - Michal Petrilak (engineercz@gmail.com)

## Environment

The project was created in Delphi 2009.

## License

This project is distributed under Apache License v2.0.
