COMPONENT=sendAckAppC
BUILD_EXTRA_DEPS += sendAck.class
CLEAN_EXTRA = *.class sendAckMsg.java

CFLAGS += -I$(TOSDIR)/lib/T2Hack

sendAck.class: $(wildcard *.java) sendAckMsg.java
	javac *.java

sendAckMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=sendAckMsg sendAck.h my_msg4 -o $@

include $(MAKERULES)
