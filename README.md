# Waste management system

The waste management system is a network of smart bins connected to a
garbage truck which picks up the trash.

## Functionality

* **Trash phase:** this is a simulation of the action of taking out the
garbage and it is performed only by the bin motes. Periodically, in a
random interval between 1 and 30 seconds, a new trash is thrown in
the bin. Such trash is still a random value, between 1 and 10 units. If
the condition of the following point is fulfilled the new trash value is
added to the current value.
* **Sensing phase:** After every action described above the bin checks its
filling level. Three are three possible cases:
    1. **Level < 85 → NORMAL STATUS**: the garbage is correctly
    collected by the bin.
    2. **85 ≤ Level < 100 → CRITICAL STATUS**: the garbage
    is correctly gathered, but the bin is almost full. Go on **ALERT
    MODE**.
    3. **Level ≥ 100 → FULL STATUS**: the current trash cannot be
    collected by the bin and it must be moved to the closest bin. Go
    on **FULL MODE**.
* **Alert mode:** when the status of the bin is critical, it starts to transmit
periodical ALERT messages to the garbage truck. That messages contain the 
position (X,Y) of the bin and its ID. When the truck receives
the message it travels to the bin in a travel time directly proportional
to the distance between the two motes. In order to simulate the trip
time a timer is used. The truck computes the distance truck-bin and,
after a t_truck time, it sends back to the bin a TRUCK message that
simulate the arrival of the truck. Upon the receiving of the TRUCK
message, the bin empties its filling level (set it to 0) and sends back an
ACK.
* **Neighbor mode:** when the bin is completely full, it cannot store the
trash anymore. The garbage that is still being generated must be sent
somewhere else. For this purpose, the bin broadcasts a MOVE message,
this special type of message can be read only by the other bin motes.
When a neighbor receives a MOVE message, if its status is NORMAL,
it replies with its (X,Y) coordinates after a t_bin time. The requester
bin waits 2 seconds for collecting all the messages, then computes the
distance with the neighbors that have replied and sends the exceeding
trash to its closest neighbor with a message. If no neighbor replies, it
raises an error and deletes that piece of garbage.

## Technical details

The travel time (that is actually only a delay) between the motes is:

**t = α x (Euclidean distance between the two motes)**

where α_bin→bin << α_bin→truck.