#include <stdlib.h>
#include <time.h>
int main(){
	struct timespec tim;
	tim.tv_sec=0;
	tim.tv_nsec=500000000L;

	while(1){
		system("cat /sys/bus/iio/devices/iio:device0/in_accel_x_raw > /dev/null");
		system("cat /sys/bus/iio/devices/iio:device0/in_accel_y_raw > /dev/null");
		system("cat /sys/bus/iio/devices/iio:device0/in_accel_z_raw > /dev/null");
  		nanosleep(&tim, NULL);
	}
	return 0;
}

