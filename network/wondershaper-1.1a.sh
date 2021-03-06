#!/bin/bash
# Wonder Shaper
# please read the README before filling out these values 
#
# Set the following values to somewhat less than your actual download
# and uplink speed. In kilobits. Also set the device that is to be shaped.

DOWNLINK=800
UPLINK=220
DEV=ppp0

# low priority OUTGOING traffic - you can leave this blank if you want
# low priority source netmasks
NOPRIOHOSTSRC=

# low priority destination netmasks
NOPRIOHOSTDST=

# low priority source ports
NOPRIOPORTSRC=

# low priority destination ports
NOPRIOPORTDST=


# Now remove the following two lines :-)

echo Please read the documentation in 'README' first
exit

if [ "$1" = "status" ]
then
	tc -s qdisc ls dev $DEV
	tc -s class ls dev $DEV
	exit
fi


# clean existing down- and uplink qdiscs, hide errors
tc qdisc del dev $DEV root    2> /dev/null > /dev/null
tc qdisc del dev $DEV ingress 2> /dev/null > /dev/null

if [ "$1" = "stop" ] 
then 
	exit
fi


###### uplink

# install root HTB, point default traffic to 1:20:

tc qdisc add dev $DEV root handle 1: htb default 20

# shape everything at $UPLINK speed - this prevents huge queues in your
# DSL modem which destroy latency:

tc class add dev $DEV parent 1: classid 1:1 htb rate ${UPLINK}kbit burst 6k

# high prio class 1:10:

tc class add dev $DEV parent 1:1 classid 1:10 htb rate ${UPLINK}kbit \
   burst 6k prio 1

# bulk & default class 1:20 - gets slightly less traffic, 
# and a lower priority:

tc class add dev $DEV parent 1:1 classid 1:20 htb rate $[9*$UPLINK/10]kbit \
   burst 6k prio 2

tc class add dev $DEV parent 1:1 classid 1:30 htb rate $[8*$UPLINK/10]kbit \
   burst 6k prio 2

# all get Stochastic Fairness:
tc qdisc add dev $DEV parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev $DEV parent 1:20 handle 20: sfq perturb 10
tc qdisc add dev $DEV parent 1:30 handle 30: sfq perturb 10

# TOS Minimum Delay (ssh, NOT scp) in 1:10:

tc filter add dev $DEV parent 1:0 protocol ip prio 10 u32 \
      match ip tos 0x10 0xff  flowid 1:10

# ICMP (ip protocol 1) in the interactive class 1:10 so we 
# can do measurements & impress our friends:
tc filter add dev $DEV parent 1:0 protocol ip prio 10 u32 \
        match ip protocol 1 0xff flowid 1:10

# To speed up downloads while an upload is going on, put ACK packets in
# the interactive class:

tc filter add dev $DEV parent 1: protocol ip prio 10 u32 \
   match ip protocol 6 0xff \
   match u8 0x05 0x0f at 0 \
   match u16 0x0000 0xffc0 at 2 \
   match u8 0x10 0xff at 33 \
   flowid 1:10

# rest is 'non-interactive' ie 'bulk' and ends up in 1:20

# some traffic however suffers a worse fate
for a in $NOPRIOPORTDST
do
	tc filter add dev $DEV parent 1: protocol ip prio 14 u32 \
	   match ip dport $a 0xffff flowid 1:30
done

for a in $NOPRIOPORTSRC
do
 	tc filter add dev $DEV parent 1: protocol ip prio 15 u32 \
	   match ip sport $a 0xffff flowid 1:30
done

for a in $NOPRIOHOSTSRC
do
 	tc filter add dev $DEV parent 1: protocol ip prio 16 u32 \
	   match ip src $a flowid 1:30
done

for a in $NOPRIOHOSTDST
do
 	tc filter add dev $DEV parent 1: protocol ip prio 17 u32 \
	   match ip dst $a flowid 1:30
done

# rest is 'non-interactive' ie 'bulk' and ends up in 1:20

tc filter add dev $DEV parent 1: protocol ip prio 18 u32 \
   match ip dst 0.0.0.0/0 flowid 1:20


########## downlink #############
# slow downloads down to somewhat less than the real speed  to prevent 
# queuing at our ISP. Tune to see how high you can set it.
# ISPs tend to have *huge* queues to make sure big downloads are fast
#
# attach ingress policer:

tc qdisc add dev $DEV handle ffff: ingress

# filter *everything* to it (0.0.0.0/0), drop everything that's
# coming in too fast:

tc filter add dev $DEV parent ffff: protocol ip prio 50 u32 match ip src \
   0.0.0.0/0 police rate ${DOWNLINK}kbit burst 10k drop flowid :1


                                                                                                                                                                                                                                                                                            wondershaper-1.1a/wshaper                                                                           0100755 0001750 0001750 00000007374 07457032233 013751  0                                                                                                    ustar   ahu                             ahu                                                                                                                                                                                                                    #!/bin/bash 

# Wonder Shaper
# please read the README before filling out these values 
#
# Set the following values to somewhat less than your actual download
# and uplink speed. In kilobits. Also set the device that is to be shaped.
DOWNLINK=800
UPLINK=220
DEV=eth0

# low priority OUTGOING traffic - you can leave this blank if you want
# low priority source netmasks
NOPRIOHOSTSRC=80

# low priority destination netmasks
NOPRIOHOSTDST=

# low priority source ports
NOPRIOPORTSRC=

# low priority destination ports
NOPRIOPORTDST=

# Now remove the following two lines :-)

echo Please read the documentation in 'README' first :-\)
exit

#########################################################

if [ "$1" = "status" ]
then
	tc -s qdisc ls dev $DEV
	tc -s class ls dev $DEV
	exit
fi


# clean existing down- and uplink qdiscs, hide errors
tc qdisc del dev $DEV root    2> /dev/null > /dev/null
tc qdisc del dev $DEV ingress 2> /dev/null > /dev/null

if [ "$1" = "stop" ] 
then 
	exit
fi

###### uplink

# install root CBQ

tc qdisc add dev $DEV root handle 1: cbq avpkt 1000 bandwidth 10mbit 

# shape everything at $UPLINK speed - this prevents huge queues in your
# DSL modem which destroy latency:
# main class

tc class add dev $DEV parent 1: classid 1:1 cbq rate ${UPLINK}kbit \
allot 1500 prio 5 bounded isolated 

# high prio class 1:10:

tc class add dev $DEV parent 1:1 classid 1:10 cbq rate ${UPLINK}kbit \
   allot 1600 prio 1 avpkt 1000

# bulk and default class 1:20 - gets slightly less traffic, 
#  and a lower priority:

tc class add dev $DEV parent 1:1 classid 1:20 cbq rate $[9*$UPLINK/10]kbit \
   allot 1600 prio 2 avpkt 1000

# 'traffic we hate'

tc class add dev $DEV parent 1:1 classid 1:30 cbq rate $[8*$UPLINK/10]kbit \
   allot 1600 prio 2 avpkt 1000

# all get Stochastic Fairness:
tc qdisc add dev $DEV parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev $DEV parent 1:20 handle 20: sfq perturb 10
tc qdisc add dev $DEV parent 1:30 handle 30: sfq perturb 10

# start filters
# TOS Minimum Delay (ssh, NOT scp) in 1:10:
tc filter add dev $DEV parent 1:0 protocol ip prio 10 u32 \
      match ip tos 0x10 0xff  flowid 1:10

# ICMP (ip protocol 1) in the interactive class 1:10 so we 
# can do measurements & impress our friends:
tc filter add dev $DEV parent 1:0 protocol ip prio 11 u32 \
        match ip protocol 1 0xff flowid 1:10

# prioritize small packets (<64 bytes)

tc filter add dev $DEV parent 1: protocol ip prio 12 u32 \
   match ip protocol 6 0xff \
   match u8 0x05 0x0f at 0 \
   match u16 0x0000 0xffc0 at 2 \
   flowid 1:10


# some traffic however suffers a worse fate
for a in $NOPRIOPORTDST
do
	tc filter add dev $DEV parent 1: protocol ip prio 14 u32 \
	   match ip dport $a 0xffff flowid 1:30
done

for a in $NOPRIOPORTSRC
do
 	tc filter add dev $DEV parent 1: protocol ip prio 15 u32 \
	   match ip sport $a 0xffff flowid 1:30
done

for a in $NOPRIOHOSTSRC
do
 	tc filter add dev $DEV parent 1: protocol ip prio 16 u32 \
	   match ip src $a flowid 1:30
done

for a in $NOPRIOHOSTDST
do
 	tc filter add dev $DEV parent 1: protocol ip prio 17 u32 \
	   match ip dst $a flowid 1:30
done

# rest is 'non-interactive' ie 'bulk' and ends up in 1:20

tc filter add dev $DEV parent 1: protocol ip prio 18 u32 \
   match ip dst 0.0.0.0/0 flowid 1:20


########## downlink #############
# slow downloads down to somewhat less than the real speed  to prevent 
# queuing at our ISP. Tune to see how high you can set it.
# ISPs tend to have *huge* queues to make sure big downloads are fast
#
# attach ingress policer:

tc qdisc add dev $DEV handle ffff: ingress

# filter *everything* to it (0.0.0.0/0), drop everything that's
# coming in too fast:

tc filter add dev $DEV parent ffff: protocol ip prio 50 u32 match ip src \
   0.0.0.0/0 police rate ${DOWNLINK}kbit burst 10k drop flowid :1

                                                                                                                                                                                                                                                                    wondershaper-1.1a/README                                                                            0100644 0001750 0001750 00000021464 07457032355 013233  0                                                                                                    ustar   ahu                             ahu                                                                                                                                                                                                                    The Wonder Shaper		1.1a
bert hubert <ahu@ds9a.nl>
http://lartc.org/wondershaper
(c) Copyright 2002 
Licenced under the GPL - see 'COPYING'

This document is a bit long, I'll split it up later.
The very short summary is: edit the first few lines of 'wshaper' and run it.

GOALS
-----

I attempted to create the holy grail:

	* Maintain low latency for interfactive traffic at all times

This means that downloading or uploading files should not disturb SSH or
even telnet. These are the most important things, even 200ms latency is
sluggish to work over.

	* Allow 'surfing' at reasonable speeds while up or downloading

Even though http is 'bulk' traffic, other traffic should not drown it out
too much.

	* Make sure uploads don't harm downloads, and the other way around

This is a much observed phenomenon where upstream traffic simply destroys
download speed. It turns out that all this is possible, at the cost of a
tiny bit of bandwidth. The reason that uploads, downloads and ssh hurt
eachother is the presence of large queues in many domestic access devices
like cable or DSL modems.

	* Have the ability to mark certain hosts/ports as 'low priority'

If you *know* which hosts or ports are hogging your outgoing link, be able
to deprioritize it.

The next section explains in depth what causes delays, and how we can fix
them. You can safely skip it and head straight for the script if you don't
care how the magic is performed.

Before emailing me or the mailinglist PLEASE read the 'known problems'
section.

Why it doesn't work well by default
-----------------------------------

ISPs know that they are benchmarked solely on how fast people can download.
Besides available bandwidth, download speed is influenced heavily by packet
loss, which seriously hampers TCP/IP performance. Large queues can help
prevent packetloss, and speed up downloads. So ISPs configure large queues.

These large queues however damage interactivity. A keystroke must first
travel the upstream queue, which may be seconds (!) long and go to your
remote host. It is then displayed, which leads to a packet coming back,
which must then traverse the downstream queue, located at your ISP, before
it appears on your screen.

This HOWTO teaches you how to mangle and process the queue in many ways, but
sadly, not all queues are accessible to us. The queue over at the ISP is
completely off-limits, whereas the upstream queue probably lives inside your
cable modem or DSL device. You may or may not be able to configure it. Most
probably not.

So, what next? As we can't control either of those queues, they must be
eliminated, and moved to your Linux router. Luckily this is possible.

Limit upload speed somewhat
---------------------------

By limiting our upload speed to slightly less than the truly available rate,
no queues are built up in our modem. The queue is now moved to Linux. 

Limit download speed
--------------------

This is slightly trickier as we can't really influence how fast the internet
ships us data. We can however drop packets that are coming in too fast,
which causes TCP/IP to slow down to just the rate we want. Because we don't
want to drop traffic unnecessarily, we configure a 'burst' size we allow at
higher speed.

Now, once we have done this, we have eliminated the downstream queue totally
(except for short bursts), and gain the ability to manage the upstream queue
with all the power Linux offers.

Let interactive traffic skip the queue
--------------------------------------

What remains to be done is to make sure interactive traffic jumps to the
front of the upstream queue. To make sure that uploads don't hurt downloads,
we also move ACK packets to the front of the queue. This is what normally
causes the huge slowdown observed when generating bulk traffic both ways.
The ACKnowledgements for downstream traffic must compete with upstream
traffic, and get delayed in the process.

We also move other small packets to the front of the queue - this helps
operating systems which do not set TOS bits, like everything from Microsoft.

Allow the user to specify low priority traffic (new in 1.1!)
------------------------------------------------------------

Sometimes you may notice low priority OUTGOING traffic slowing down
important traffic. In that case, the following options may help you:

NOPRIOHOSTSRC
	Set this to hosts or netmasks in your network that should have low
	priority

NOPRIOHOSTDST
	Set this to hosts or netmasks on the internet that should have low
	priority

NOPRIOPORTSRC
	Set this to source ports that should have low priority. If you have
	an unimportant webserver on your traffic, set this to 80

NOPRIOPORTDST
	Set this to destination ports that should have low priority. 

See the start of wshaper and wshaper.htb

Results
-------

If we do all this we get the following measurements using an excellent ADSL
connection from xs4all in the Netherlands:

Baseline latency:
round-trip min/avg/max = 14.4/17.1/21.7 ms

Without traffic conditioner, while downloading:
round-trip min/avg/max = 560.9/573.6/586.4 ms

Without traffic conditioner, while uploading:
round-trip min/avg/max = 2041.4/2332.1/2427.6 ms

With conditioner, during 220kbit/s upload:
round-trip min/avg/max = 15.7/51.8/79.9 ms

With conditioner, during 850kbit/s download:
round-trip min/avg/max = 20.4/46.9/74.0 ms

When uploading, downloads proceed at ~80% of the available speed. Uploads
at around 90%. Latency then jumps to 850 ms, still figuring out why.

What you can expect from this script depends a lot on your actual uplink
speed. When uploading at full speed, there will always be a single packet
ahead of your keystroke. That is the lower limit to the latency you can
achieve - divide your MTU by your upstream speed to calculate. Typical
values will be somewhat higher than that. Lower your MTU for better effects!

A small table:

Uplink speed   |  Expected latency due to upload
--------------------------------------------------
32             |  234ms
64             |  117ms
128            |  58ms
256            |  29ms

So to calculate your effective latency, take a baseline measurement (ping on
an unloaded link), and look up the number in the table, and add it. That is
about the best you can expect. This number comes from a calculation that
assumes that your upstream keystroke will have at most half a full sized
packet ahead of it.

This boils down to:

   mtu * 0.5 * 10
   --------------  + baseline_latency
       kbit

The factor 10 is not quite correct but works well in practice.

Your kernel
-----------

If you run a recent distribution, everything should be ok. You need 2.4 with
QoS options turned on. 

If you compile your own kernel, it must have some options enabled. Most
notably, in the Networking Options menu, QoS and/or Fair Queueing, turn at
least CBQ, PRIO, SFQ, Ingress, Traffic Policing, QoS support, Rate
Estimator, QoS classifier, U32 classifier, fwmark classifier.

In practice, I (and most distributions) just turn on everything.

The scripts
-----------

The script comes in two versions, one which works on standard kernels and is
implemented using CBQ. The other one uses the excellent HTB qdisc which is
not in the default kernel. The CBQ version is more tested than the HTB one!

See 'wshaper' and 'wshaper.htb'. 

Tuning
------

These scripts need to know the 'real' rate of your ISP connection. This is
hard to determine upfront as different ISPs use different kinds of bits it
appears. People report success using the following technique:

Estimate both your upstream and downstream at half the rate your ISP
specifies. Now verify if the script is functioning - check interactivity
while uploading and while downloading. This should deliver the latency as
calculated above. If not, check if the script executed without errors.

Now slowly increase the upstream & downstream numbers in the script until
the latency comes back. This way you can find optimum values for your
connection. If you are happy, please report to me so I can make a list of
numbers that work well. Please let me know which ISP you use and the name of
your subscription, and its reputed specifications, so I can list you here
and save others the trouble.

Installation
------------

If you dial in, you can copy the script to /etc/ppp/ip-up.d and it will be
run at each connect.

If you want to remove the shaper from an interface, run 'wshaper stop'. To
see status information, run 'wshaper status'.

KNOWN PROBLEMS
--------------

If you get errors, add an -x to the first line, as follows:

#!/bin/bash -x

And retry. This will show you which line gives an error. Before contacting
me, make sure that you are running a recent version of iproute!

Recent versions can be found at your Linux distributor, or if you prefer
compiling, here: ftp://ftp.inr.ac.ru/ip-routing/iproute2-current.tar.gz

More information
----------------

Information on how this all works can be found on http://lartc.org
The Linux Advanced Routing & Traffic Control HOWTO site.
                                                                                                                                                                                                            wondershaper-1.1a/COPYING                                                                           0100644 0001750 0001750 00000043110 07441234646 013376  0                                                                                                    ustar   ahu                             ahu                                                                                                                                                                                                                    		    GNU GENERAL PUBLIC LICENSE
		       Version 2, June 1991

 Copyright (C) 1989, 1991 Free Software Foundation, Inc.
     59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

			    Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
License is intended to guarantee your freedom to share and change free
software--to make sure the software is free for all its users.  This
General Public License applies to most of the Free Software
Foundation's software and to any other program whose authors commit to
using it.  (Some other Free Software Foundation software is covered by
the GNU Library General Public License instead.)  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
this service if you wish), that you receive source code or can get it
if you want it, that you can change the software or use pieces of it
in new free programs; and that you know you can do these things.

  To protect your rights, we need to make restrictions that forbid
anyone to deny you these rights or to ask you to surrender the rights.
These restrictions translate to certain responsibilities for you if you
distribute copies of the software, or if you modify it.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must give the recipients all the rights that
you have.  You must make sure that they, too, receive or can get the
source code.  And you must show them these terms so they know their
rights.

  We protect your rights with two steps: (1) copyright the software, and
(2) offer you this license which gives you legal permission to copy,
distribute and/or modify the software.

  Also, for each author's protection and ours, we want to make certain
that everyone understands that there is no warranty for this free
software.  If the software is modified by someone else and passed on, we
want its recipients to know that what they have is not the original, so
that any problems introduced by others will not reflect on the original
authors' reputations.

  Finally, any free program is threatened constantly by software
patents.  We wish to avoid the danger that redistributors of a free
program will individually obtain patent licenses, in effect making the
program proprietary.  To prevent this, we have made it clear that any
patent must be licensed for everyone's free use or not licensed at all.

  The precise terms and conditions for copying, distribution and
modification follow.

		    GNU GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License applies to any program or other work which contains
a notice placed by the copyright holder saying it may be distributed
under the terms of this General Public License.  The "Program", below,
refers to any such program or work, and a "work based on the Program"
means either the Program or any derivative work under copyright law:
that is to say, a work containing the Program or a portion of it,
either verbatim or with modifications and/or translated into another
language.  (Hereinafter, translation is included without limitation in
the term "modification".)  Each licensee is addressed as "you".

Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running the Program is not restricted, and the output from the Program
is covered only if its contents constitute a work based on the
Program (independent of having been made by running the Program).
Whether that is true depends on what the Program does.

  1. You may copy and distribute verbatim copies of the Program's
source code as you receive it, in any medium, provided that you
conspicuously and appropriately publish on each copy an appropriate
copyright notice and disclaimer of warranty; keep intact all the
notices that refer to this License and to the absence of any warranty;
and give any other recipients of the Program a copy of this License
along with the Program.

You may charge a fee for the physical act of transferring a copy, and
you may at your option offer warranty protection in exchange for a fee.

  2. You may modify your copy or copies of the Program or any portion
of it, thus forming a work based on the Program, and copy and
distribute such modifications or work under the terms of Section 1
above, provided that you also meet all of these conditions:

    a) You must cause the modified files to carry prominent notices
    stating that you changed the files and the date of any change.

    b) You must cause any work that you distribute or publish, that in
    whole or in part contains or is derived from the Program or any
    part thereof, to be licensed as a whole at no charge to all third
    parties under the terms of this License.

    c) If the modified program normally reads commands interactively
    when run, you must cause it, when started running for such
    interactive use in the most ordinary way, to print or display an
    announcement including an appropriate copyright notice and a
    notice that there is no warranty (or else, saying that you provide
    a warranty) and that users may redistribute the program under
    these conditions, and telling the user how to view a copy of this
    License.  (Exception: if the Program itself is interactive but
    does not normally print such an announcement, your work based on
    the Program is not required to print an announcement.)

These requirements apply to the modified work as a whole.  If
identifiable sections of that work are not derived from the Program,
and can be reasonably considered independent and separate works in
themselves, then this License, and its terms, do not apply to those
sections when you distribute them as separate works.  But when you
distribute the same sections as part of a whole which is a work based
on the Program, the distribution of the whole must be on the terms of
this License, whose permissions for other licensees extend to the
entire whole, and thus to each and every part regardless of who wrote it.

Thus, it is not the intent of this section to claim rights or contest
your rights to work written entirely by you; rather, the intent is to
exercise the right to control the distribution of derivative or
collective works based on the Program.

In addition, mere aggregation of another work not based on the Program
with the Program (or with a work based on the Program) on a volume of
a storage or distribution medium does not bring the other work under
the scope of this License.

  3. You may copy and distribute the Program (or a work based on it,
under Section 2) in object code or executable form under the terms of
Sections 1 and 2 above provided that you also do one of the following:

    a) Accompany it with the complete corresponding machine-readable
    source code, which must be distributed under the terms of Sections
    1 and 2 above on a medium customarily used for software interchange; or,

    b) Accompany it with a written offer, valid for at least three
    years, to give any third party, for a charge no more than your
    cost of physically performing source distribution, a complete
    machine-readable copy of the corresponding source code, to be
    distributed under the terms of Sections 1 and 2 above on a medium
    customarily used for software interchange; or,

    c) Accompany it with the information you received as to the offer
    to distribute corresponding source code.  (This alternative is
    allowed only for noncommercial distribution and only if you
    received the program in object code or executable form with such
    an offer, in accord with Subsection b above.)

The source code for a work means the preferred form of the work for
making modifications to it.  For an executable work, complete source
code means all the source code for all modules it contains, plus any
associated interface definition files, plus the scripts used to
control compilation and installation of the executable.  However, as a
special exception, the source code distributed need not include
anything that is normally distributed (in either source or binary
form) with the major components (compiler, kernel, and so on) of the
operating system on which the executable runs, unless that component
itself accompanies the executable.

If distribution of executable or object code is made by offering
access to copy from a designated place, then offering equivalent
access to copy the source code from the same place counts as
distribution of the source code, even though third parties are not
compelled to copy the source along with the object code.

  4. You may not copy, modify, sublicense, or distribute the Program
except as expressly provided under this License.  Any attempt
otherwise to copy, modify, sublicense or distribute the Program is
void, and will automatically terminate your rights under this License.
However, parties who have received copies, or rights, from you under
this License will not have their licenses terminated so long as such
parties remain in full compliance.

  5. You are not required to accept this License, since you have not
signed it.  However, nothing else grants you permission to modify or
distribute the Program or its derivative works.  These actions are
prohibited by law if you do not accept this License.  Therefore, by
modifying or distributing the Program (or any work based on the
Program), you indicate your acceptance of this License to do so, and
all its terms and conditions for copying, distributing or modifying
the Program or works based on it.

  6. Each time you redistribute the Program (or any work based on the
Program), the recipient automatically receives a license from the
original licensor to copy, distribute or modify the Program subject to
these terms and conditions.  You may not impose any further
restrictions on the recipients' exercise of the rights granted herein.
You are not responsible for enforcing compliance by third parties to
this License.

  7. If, as a consequence of a court judgment or allegation of patent
infringement or for any other reason (not limited to patent issues),
conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot
distribute so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you
may not distribute the Program at all.  For example, if a patent
license would not permit royalty-free redistribution of the Program by
all those who receive copies directly or indirectly through you, then
the only way you could satisfy both it and this License would be to
refrain entirely from distribution of the Program.

If any portion of this section is held invalid or unenforceable under
any particular circumstance, the balance of the section is intended to
apply and the section as a whole is intended to apply in other
circumstances.

It is not the purpose of this section to induce you to infringe any
patents or other property right claims or to contest validity of any
such claims; this section has the sole purpose of protecting the
integrity of the free software distribution system, which is
implemented by public license practices.  Many people have made
generous contributions to the wide range of software distributed
through that system in reliance on consistent application of that
system; it is up to the author/donor to decide if he or she is willing
to distribute software through any other system and a licensee cannot
impose that choice.

This section is intended to make thoroughly clear what is believed to
be a consequence of the rest of this License.

  8. If the distribution and/or use of the Program is restricted in
certain countries either by patents or by copyrighted interfaces, the
original copyright holder who places the Program under this License
may add an explicit geographical distribution limitation excluding
those countries, so that distribution is permitted only in or among
countries not thus excluded.  In such case, this License incorporates
the limitation as if written in the body of this License.

  9. The Free Software Foundation may publish revised and/or new versions
of the General Public License from time to time.  Such new versions will
be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

Each version is given a distinguishing version number.  If the Program
specifies a version number of this License which applies to it and "any
later version", you have the option of following the terms and conditions
either of that version or of any later version published by the Free
Software Foundation.  If the Program does not specify a version number of
this License, you may choose any version ever published by the Free Software
Foundation.

  10. If you wish to incorporate parts of the Program into other free
programs whose distribution conditions are different, write to the author
to ask for permission.  For software which is copyrighted by the Free
Software Foundation, write to the Free Software Foundation; we sometimes
make exceptions for this.  Our decision will be guided by the two goals
of preserving the free status of all derivatives of our free software and
of promoting the sharing and reuse of software generally.

			    NO WARRANTY

  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR OR CORRECTION.

  12. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.

		     END OF TERMS AND CONDITIONS

	    How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
convey the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


Also add information on how to contact you by electronic and paper mail.

If the program is interactive, make it output a short notice like this
when it starts in an interactive mode:

    Gnomovision version 69, Copyright (C) year  name of author
    Gnomovision comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type `show c' for details.

The hypothetical commands `show w' and `show c' should show the appropriate
parts of the General Public License.  Of course, the commands you use may
be called something other than `show w' and `show c'; they could even be
mouse-clicks or menu items--whatever suits your program.

You should also get your employer (if you work as a programmer) or your
school, if any, to sign a "copyright disclaimer" for the program, if
necessary.  Here is a sample; alter the names:

  Yoyodyne, Inc., hereby disclaims all copyright interest in the program
  `Gnomovision' (which makes passes at compilers) written by James Hacker.

  <signature of Ty Coon>, 1 April 1989
  Ty Coon, President of Vice

This General Public License does not permit incorporating your program into
proprietary programs.  If your program is a subroutine library, you may
consider it more useful to permit linking proprietary applications with the
library.  If this is what you want to do, use the GNU Library General
Public License instead of this License.
                                                                                                                                                                                                                                                                                                                                                                                                                                                        wondershaper-1.1a/VERSION                                                                           0100644 0001750 0001750 00000000006 07457032350 013403  0                                                                                                    ustar   ahu                             ahu                                                                                                                                                                                                                    1.1a

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          wondershaper-1.1a/TODO                                                                              0100644 0001750 0001750 00000000061 07456627377 013046  0                                                                                                    ustar   ahu                             ahu                                                                                                                                                                                                                    - move configuration away from the script itself
                                                                                                                                                                                                                                                                                                                                                                                                                                                                               wondershaper-1.1a/ChangeLog                                                                         0100644 0001750 0001750 00000000366 07457032340 014115  0                                                                                                    ustar   ahu                             ahu                                                                                                                                                                                                                    Changes since version 1.1:
	- Georg Wild <georg.wild@gmx.de> noticed that
	  NOPRIOHOSTDST was never used

Changes since version 1.0:

	- we now prioritize ALL small packets, not just acks
	- ability to deprioritize certain source/dst host/ports
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          