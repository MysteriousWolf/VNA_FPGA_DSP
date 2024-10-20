# Registry Information
This document describes the FPGA configuration and data readout.
## Registry map
| Name						| Address	| Direction	| Map											|
| :------------------------ | :-------: | :-------: | :--------------------------------------------	|
| General settings			| 0000000	| W		| [23:2]: 0, 1: FIR flush[^1], 0: RST
| General status			| 0000001	| R		| [23:1]: 0, 0: PLL lock
| Conversion control		| 0000010	| R/W	| [23:14]: 0, 13: Start conversion, [12:0]: Point count
| Conversion status			| 0000011	| R		| [23:14]: 0, R13: Conversion done, [12:0]: Converted point count
| Readout 					| 0000100	| R/W	| [R23:0]: Next data \| [W23:1]: 0, W0: Restart readout
| Readout status			| 0000101	| R		| [23:14]: 0, 13: Readout done, [12:0] Current index
| FIR Shift[^1]				| 0100000	| R/W	| [23:5]: 0, [4:0]: FIR shift (divider 2^n)
| Previous transaction[^1]	| 0111110	| R		| [23:0]: Last data received by the FPGA
| Device ID[^1]				| 0111111	| R		| [23:0]: device ID
| FIR Coefs[^1]				|100xxxx[^2]| R/W	| [23:0]: FIR coefficients

[^1]: This option is currently disabled due to the limited implementation
[^2]: The `xxxx` part is the coefficient index for this item