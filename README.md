# B2BDC
Adding B2B direct connect organizations is a tedious and error-prone task, so a script should handle this much better.

#### To list all organizations with B2B direct connect configured, and also EDU in .no with number of regular b2b guests.
``` PowerShell
.\b2bdc.ps1
```
#### To add UiO by domain (uio.no) with default settings, and all inbound and outbound users allowed
.\b2bdc.ps1 -Target uio.no

#### To add UiO by tenant ID with default settings, and all inbound and outbound users allowed
.\b2bdc.ps1 -Target 463b6811-b0a4-4b2a-b932-72c4c970c5d2

#### To add UiO by domain (uio.no) with a single group for outbound allowed and all inbound allowed
.\b2bdc.ps1 -Target uio.no -OutboundGroup bb368b82-5fb0-49bc-913b-ec23ec28daf5

#### To add UiO by domain (uio.no) with a single group for outbound allowed, and a single group for inbound allowed
.\b2bdc.ps1 -Target uio.no -OutboundGroup bb368b82-5fb0-49bc-913b-ec23ec28daf5 -OutboundGroup br366b82-54b0-46bc-923b-ecjgu57tywhc

#### To add UiO by domain (uio.no) with two groups for outbound allowed and all inbound allowed
.\b2bdc.ps1 -Target uio.no -OutboundGroup bb368b82-5fb0-49bc-913b-ec23ec28daf5,b7597783-377e-4589-b464-d42f6b947bb4
