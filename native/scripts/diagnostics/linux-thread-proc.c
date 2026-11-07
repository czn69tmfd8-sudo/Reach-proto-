/* Check live-thread proc visibility without Swift, XCTest, or dispatch. */
#define _GNU_SOURCE
#include <pthread.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
static void *worker(void *unused) {
 char path[128]; long tid=syscall(SYS_gettid);
 snprintf(path,sizeof(path),"/proc/%ld/stat",tid);
 int fd=open(path,O_RDONLY|O_NONBLOCK); int err=fd<0?errno:0;
 printf("getpid=%d gettid=%ld proc-tid fd=%d errno=%d\n",getpid(),tid,fd,err); if(fd>=0)close(fd);
 snprintf(path,sizeof(path),"/proc/self/task/%ld/stat",tid);
 fd=open(path,O_RDONLY|O_NONBLOCK);err=fd<0?errno:0;
 printf("proc-self-task fd=%d errno=%d\n",fd,err);if(fd>=0)close(fd);
 return NULL;
}
int main(void){pthread_t t;pthread_create(&t,NULL,worker,NULL);pthread_join(t,NULL);return 0;}
