COMPONENT=sendAckAppC
BUILD_EXTRA_DEPS += SendAck.class
CLEAN_EXTRA = *.class SendAckMsg.java

CFLAGS += -I$(TOSDIR)/lib/T2Hack

SendAck.class: $(wildcard *.java) SendAckMsg.java
	javac *.java

SendAckMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=SendAckMsg sendAck.h my_msg4 -o $@

include $(MAKERULES)
