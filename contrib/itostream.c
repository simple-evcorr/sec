/*
  SEC plugin for HP OV ITO/Operations (contributed by Risto Vaarandi).
  This program reads events from HP OV ITO (now known as HP OV Operations)
  server or agent event stream and writes them to standard output. Its main 
  task is to act as a link between ITO and an external message processing
  application (e.g., a correlation engine). The program has been tested with
  ITO 5.3, 6.0, 7.1, 8.1 and 9.2
  
  This program takes 2 commandline parameters:
  
  MSI interface - name used internally by ITO to denote the interface that
                  is used for passing messages to this program. You can
                  pick up arbitrary name, provided that it meets naming
                  convention used by ITO (see ITO Application Integration 
                  Guide for more information). Generally, using up to 12 
                  a-z characters as a name should be safe.
  reopen timeout - if there has been no new data for a given number of 
                   seconds, reopen the interface. Using 0 as a value
                   disables reopening.


  Compiling for Operations 9.2 server on Centos6:
  gcc -o itostream itostream.c -L/opt/OV/lib64 -lopcsv_r \
                               -Xlinker '-rpath=/opt/OV/lib64'

  Compiling for ITO server on Solaris/HP-UX (older versions):
  gcc -o itostream itostream.c -L/opt/OV/lib -lopcsv -lnsp
  
  Compiling for ITO agent:
  gcc -o itostream itostream.c -DAGENT -L/opt/OV/lib -lopc -lnsp

  Since ITO agent installation is sometimes broken, you might not have libopc 
  in /opt/OV/lib (which normally is just a symbolic link to libopc_r or some 
  other library in the same directory). In that case you could just try:
  gcc -o itostream itostream.c -DAGENT -L/opt/OV/lib -lopc_r -lnsp

  Compiled program needs root-privileges for running. 
  If ITO shared libraries are not found when starting the program, recompile
  with additional options -Xlinker -rpath /opt/OV/lib
*/

#include <stdio.h>                      /* stdio stuff */
#include <stdlib.h>                     /* free(), atoi() */
#include <unistd.h>                     /* sleep() */

#ifdef AGENT
#include "/opt/OV/include/opcapi.h"     /* ITO agent-side stuff */
#else
#include "/opt/OV/include/opcsvapi.h"   /* ITO server-side stuff */
#endif

#define ERRORMSGSIZE 1024
#define SLEEPEMPTY 1	/* sleep on empty input before new read attempt */
#define SLEEPOPEN 3	/* sleep between closing and reopening the input */

void error_msg(int code, char *text)
{
  int size;
  char *ptr;

  opcdata_get_error_msg(code, &ptr, &size);
  strncpy(text, ptr, size);
  text[size] = 0;
  free(ptr);
}



int open_if(char *ifname)
{
  int ret;
  char errortext[ERRORMSGSIZE];
  int interface;


#ifdef AGENT
  ret = opcif_open(OPCAGTIF_EXTMSGPROC_READWRITE, ifname, OPCIF_SV_RUNNING | 
    OPCIF_READ_NOWAIT | OPCIF_IGNORE_MSI_ALREADY_EXISTS, 0, &interface);
#else
  ret = opcif_open(OPCSVIF_EXTMSGPROC_READWRITE, ifname, OPCIF_SV_RUNNING | 
    OPCIF_READ_NOWAIT | OPCIF_IGNORE_MSI_ALREADY_EXISTS, 0, &interface);
#endif

  if (ret != OPC_ERR_OK) {

    error_msg(ret, errortext);

    fprintf(stderr, 
      "Error opening MSI interface \"%s\": %s\n", ifname, errortext);

    exit(1);
  }

  ret = opcif_register(interface, 0, 0);

  if (ret != OPC_ERR_OK) {

    error_msg(ret, errortext);

    fprintf(stderr, 
      "Error registering condition with MSI interface \"%s\": %s\n", 
        ifname, errortext);

    opcif_close(interface);

    exit(1);
  }

  return interface;
}



void find_sev(int severity, char *text)
{

  switch(severity) {

    case OPC_SEV_UNCHANGED:
      strcpy(text, "unchanged");
      break;

    case OPC_SEV_UNKNOWN:
      strcpy(text, "unknown");
      break;

    case OPC_SEV_NORMAL:
      strcpy(text, "normal");
      break;

    case OPC_SEV_WARNING:
      strcpy(text, "warning");
      break;

    case OPC_SEV_CRITICAL:
      strcpy(text, "critical");
      break;

    case OPC_SEV_MINOR:
      strcpy(text, "minor");
      break;

    case OPC_SEV_MAJOR:
      strcpy(text, "major");
      break;

  }

}



int main(int argc, char **argv)
{
  int interface;
  int reopen, sleepcounter;
  int ret;
  char errortext[ERRORMSGSIZE];
  opcdata msg;
  long time;
  long severity;
  char sevtext[32];
  char *id, *app, *obj, *node;
  char *msg_group, *msg_text;


  if (argc < 3) {

    fprintf(stderr, 
      "Usage: %s <MSI interface name> <reopen timeout>\n", argv[0]);
    exit(1);
  }

  /* set stdout buffering to line mode
     (needed if stdout was redirected to a file or to a pipe) */
  setvbuf(stdout, 0, _IOLBF, 0); 

  interface = open_if(argv[1]);
  reopen = atoi(argv[2]);

  opcdata_create(OPCDTYPE_EMPTY, &msg);

  sleepcounter = 0;

  for (;;) {

    ret = opcif_read(interface, msg);

    switch (ret) {

      case OPC_ERR_OK:

        sleepcounter = 0;

        id = opcdata_get_str(msg, OPCDATA_MSGID);
        time = opcdata_get_long(msg, OPCDATA_CREATION_TIME);
        severity = opcdata_get_long(msg, OPCDATA_SEVERITY);
        node = opcdata_get_str(msg, OPCDATA_NODENAME);
        app = opcdata_get_str(msg, OPCDATA_APPLICATION);
        obj = opcdata_get_str(msg, OPCDATA_OBJECT);
        msg_group = opcdata_get_str(msg, OPCDATA_GROUP);
        msg_text = opcdata_get_str(msg, OPCDATA_MSGTEXT);

	find_sev(severity, sevtext);

        printf("id=%s time=%ld sev=%s node=%s app=%s obj=%s msg_grp=%s msg_text=%s\n",
          id, time, sevtext, node, app, obj, msg_group, msg_text);

        break;

      case OPC_ERR_NO_DATA:

        sleep(SLEEPEMPTY);
        sleepcounter += SLEEPEMPTY;

        if (reopen  &&  sleepcounter >= reopen) {

          fprintf(stderr, "Reopening MSI interface \"%s\"\n", argv[1]);
          sleepcounter = 0;
          opcif_close(interface);
	  sleep(SLEEPOPEN);
          interface = open_if(argv[1]);
        }

        break;

      default:

        error_msg(ret, errortext);

        fprintf(stderr, "Error reading from MSI interface \"%s\": %s\n",
          argv[1], errortext);

        opcdata_free(&msg);
        opcif_close(interface);

        exit(1);

    }

  } 

}
 
