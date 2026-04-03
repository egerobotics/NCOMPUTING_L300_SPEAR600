#include <usb.h>
#include <image.h>
#include <stdio.h>
#include <string.h>

#define printf(args...) fprintf(stderr, args)

#define MY_VID		0x0483
#define SPR6XX_PID	0x7261
#define SPR3XX_PID	0x3801
#define SPR13XX_PID	0x3802

#define DDR_DRIVER	0x11
#define FIRMWARE	0x22

#define EP_IN		0x81
#define EP_OUT		0x02

#define NUM_OF_READ_DATA	1024

#define SPEAr600	1
#define SPEAr300	2
#define SPEAr310	3
#define SPEAr320	4
#define SPEAr1300	5
#define SPEAr1310_reva	6
#define SPEAr900	7
#define SPEAr1340	8
#define SPEAr1310	9

static unsigned int imageSize;
usb_dev_handle *open_dev(void);

usb_dev_handle *usb_dev;

unsigned int Conv_BigE_2_LittleE(unsigned int bigE)
{
	unsigned int littelE;

	littelE = ((bigE << 24) & 0xff000000);
	littelE |= ((bigE << 8) & 0x00ff0000);
	littelE |= ((bigE >> 8) & 0x0000ff00);
	littelE |= ((bigE >> 24) & 0x000000ff);

	return littelE;

}

usb_dev_handle *open_dev(void)
{
	struct usb_bus *bus;
	struct usb_device *dev;

	for(bus = usb_get_busses(); bus; bus = bus->next) {
		for(dev = bus->devices; dev; dev = dev->next) {
			if((dev->descriptor.idVendor == MY_VID)
					&& ((dev->descriptor.idProduct == SPR6XX_PID)
						||(dev->descriptor.idProduct == SPR3XX_PID)
						||(dev->descriptor.idProduct == SPR13XX_PID))) {
				return usb_open(dev);
			}
		}
	}
	return NULL;
}

#define NAND_ENV 1
#define NOR_ENV 2

int main(int argc, char **argv)
{
	int env, sprdev;
	image_header_t *pImageHeader;
	unsigned int loadAddress;
	unsigned long txCnt;
	int result1;
	unsigned char buf[NUM_OF_READ_DATA];
	int readCnt = 0;
	FILE *fp = NULL;
	usb_dev_handle *dev = NULL; /* the device handle */

	env = NOR_ENV;
	sprdev = SPEAr1300;

	if ((argc != 3) || (strncmp(argv[1], "-dev", strlen("-dev")))) {
		return 1;
	} else if (!strcmp(argv[2], "SPEAr600") && !strcmp(argv[2], "SPEAr300")
			&& !strcmp(argv[2], "SPEAr310") && !strcmp(argv[2], "SPEAr320")
			&& !strcmp(argv[2], "SPEAr1300") && !strcmp(argv[2], "SPEAr900")
			&& !strcmp(argv[2], "SPEAr1310") && !strcmp(argv[2], "SPEAr1310_reva")
			&& !strcmp(argv[2], "SPEAr1340")) {
		return 1;
	} else {
		if (!strcmp(argv[2], "SPEAr600")) {
			sprdev = SPEAr600;
		} else if (!strcmp(argv[2], "SPEAr300")) {
			sprdev = SPEAr300;
		} else if (!strcmp(argv[2], "SPEAr310")) {
			sprdev = SPEAr310;
		} else if (!strcmp(argv[2], "SPEAr320")) {
			sprdev = SPEAr320;
		} else if (!strcmp(argv[2], "SPEAr1300")) {
			sprdev = SPEAr1300;
		} else if (!strcmp(argv[2], "SPEAr1310_reva")) {
			sprdev = SPEAr1310_reva;
		} else if (!strcmp(argv[2], "SPEAr1310")) {
			sprdev = SPEAr1310;
		} else if (!strcmp(argv[2], "SPEAr900")) {
			sprdev = SPEAr900;
		} else if (!strcmp(argv[2], "SPEAr1340")) {
			sprdev = SPEAr1340;
		}
	}

	usb_init(); /* initialize the library */
	usb_find_busses(); /* find all busses */
	usb_find_devices(); /* find all connected devices */

	if(!(dev = open_dev()))
	{
		printf("Device not found!");
		return -1;
	}

	if(usb_set_configuration(dev, 1) < 0)
	{
		printf("Device error!");
		usb_close(dev);
		return -1;
	}

	if(usb_claim_interface(dev, 0) < 0)
	{
		printf("Interface error!");
		usb_close(dev);
		return -1;
	}

	usb_dev = dev;

	/* open the file in binary read mode */
	if(SPEAr300 == sprdev)
		fp = fopen("./Binaries/spr300_ddrdriver.bin", "rb");
	else if(SPEAr600 == sprdev)
		fp = fopen("./Binaries/spr600_ddrdriver.bin", "rb");
	else if(SPEAr310 == sprdev)
		fp = fopen("./Binaries/spr310_ddrdriver.bin", "rb");
	else if(SPEAr320 == sprdev)
		fp = fopen("./Binaries/spr320_ddrdriver.bin", "rb");
	else if(SPEAr1300 == sprdev)
		fp = fopen("./Binaries/spr1300_ddrdriver.bin", "rb");
	else if(SPEAr1310_reva == sprdev)
		fp = fopen("./Binaries/spr1310_reva_ddrdriver.bin", "rb");
	else if(SPEAr1310 == sprdev)
		fp = fopen("./Binaries/spr1310_ddrdriver.bin", "rb");
	else if(SPEAr900 == sprdev)
		fp = fopen("./Binaries/spr900_ddrdriver.bin", "rb");
	else if(SPEAr1340 == sprdev)
		fp = fopen("./Binaries/spr1340_ddrdriver.bin", "rb");
	else
		printf("Serious error, dev not set\n");

	if (fp == NULL) {
		printf("DDR initialization not done 1. Download the DDR Driver and Firmware");
		return 1;
	}

	/* read the image header first */
	readCnt = fread(buf, 1, IH_SIZE, fp);

	if (readCnt != IH_SIZE) {
		printf("DDR initialization not done 2. Download the DDR Driver and Firmware");
		fclose(fp);
		return 1;
	}

	pImageHeader = (image_header_t *)buf;

	if (Conv_BigE_2_LittleE(pImageHeader->ih_magic) != IH_MAGIC) {
		printf("DDR initialization not done 3. Download the DDR Driver and Firmware");
		fclose(fp);
		return 1;
	}

	result1 = strncasecmp((const char *)(&pImageHeader->ih_name), "xloader", strlen("XLOADER"));

	/* is this image is of DDR driver or actual firmware? */
	if (result1 != 0) {
		/* invalid image */
		printf("DDR initialization not done 5. Download the DDR Driver and Firmware");
		fclose(fp);
		return 1;
	}

	/*
	 *
	 * Byte   0          :    Type of Data
	 * Byte   1 - 3      :    RESERVED
	 * Byte   4 - 7      :    Size of Data
	 * Byte   8 - 11     :    Load Address in RAM
	 */

	loadAddress = Conv_BigE_2_LittleE(pImageHeader->ih_load);
	imageSize = Conv_BigE_2_LittleE(pImageHeader->ih_size);

	// Send the 8 byte synchronization data first
	unsigned char sync_data[12];

	sync_data[0] = DDR_DRIVER;
	sync_data[1] = 0;
	sync_data[2] = 0;
	sync_data[3] = 0;

	/* size of data */
	sync_data[4] = (imageSize & 0xff);
	sync_data[5] = ((imageSize >> 8) & 0xff);
	sync_data[6] = ((imageSize >> 16) & 0xff);
	sync_data[7] = ((imageSize >> 24) & 0xff);

	/* load address in SRAM where the data should be loaded => 0xD2801000*/
	sync_data[8] = (loadAddress & 0xff);
	sync_data[9] = ((loadAddress >> 8) & 0xff);
	sync_data[10] = ((loadAddress >> 16) & 0xff);
	sync_data[11] = ((loadAddress >> 24) & 0xff);

	if (SPEAr1340 == sprdev || SPEAr1310 == sprdev) {
		if(usb_bulk_write(usb_dev, EP_OUT, (char*)buf, IH_SIZE, 10000) != IH_SIZE) {
			printf("DDR initialization not done 6. Download the DDR Driver and Firmware");
			exit(1);
		}
	} else {
		if(usb_bulk_write(usb_dev, EP_OUT, (char*)sync_data, 12, 10000) != 12) {
			printf("DDR initialization not done 6. Download the DDR Driver and Firmware");
			exit(1);
		}
	}

	/* set transmit count to 0 */
	txCnt = 0;
	while (1) {
		readCnt = fread(buf, 1, NUM_OF_READ_DATA, fp);
		if (readCnt <= 0) {
			if (feof(fp) != 0) {
				/* end of file */
				fclose(fp);
				break;
			}
			if (ferror(fp) != 0) {
				printf("Error reading xloader image file");
				exit(1);
			}
		}

		if(readCnt % 4)
			readCnt = (readCnt + 3) & ~3;

		if(usb_bulk_write(usb_dev, EP_OUT, (char*)buf, readCnt, 10000) !=  readCnt) {
			printf("Transmit failed 67");
			exit(1);
		}

		/* increment the transmit count if transmitted succesfully */
		txCnt += readCnt;
	}

	/* Download and run Firmware */

	/* open the file in binary read mode */
	if(SPEAr300 == sprdev) {
			fp = fopen("./Binaries/spr300_firmware.bin", "rb");
	} else if(SPEAr600 == sprdev) {
			fp = fopen("./Binaries/spr600_firmware.bin", "rb");
	} else if(SPEAr310 == sprdev) {
			fp = fopen("./Binaries/spr310_firmware.bin", "rb");
	} else if(SPEAr320 == sprdev) {
			fp = fopen("./Binaries/spr320_firmware.bin", "rb");
	} else if(SPEAr1300 == sprdev) {
			fp = fopen("./Binaries/spr1300_firmware.bin", "rb");
	} else if(SPEAr1310_reva == sprdev) {
			fp = fopen("./Binaries/spr1310_reva_firmware.bin", "rb");
	} else if(SPEAr1310 == sprdev) {
			fp = fopen("./Binaries/spr1310_firmware.bin", "rb");
	} else if(SPEAr900 == sprdev) {
			fp = fopen("./Binaries/spr900_firmware.bin", "rb");
	} else if(SPEAr1340 == sprdev) {
			fp = fopen("./Binaries/spr1340_firmware.bin", "rb");
	} else
		printf("Some serious error, sprdev not defined\n");

	if (fp == NULL) {
		printf("Firmware could not be downloaded. 1");
		return 1;
	}

	/* read the image header first */
	readCnt = fread(buf, 1, IH_SIZE, fp);

	if (readCnt != IH_SIZE) {
		printf("Firmware could not be downloaded. 2");
		fclose(fp);
		return 1;
	}

	pImageHeader = (image_header_t *)buf;

	if (Conv_BigE_2_LittleE(pImageHeader->ih_magic) != IH_MAGIC) {
		printf("Firmware could not be downloaded. 3");
		fclose(fp);
		return 1;
	}

//	result1 = strcmp((const char *)(&pImageHeader->ih_name), "FIRMWARE");
	result1 = strncasecmp((const char *)(&pImageHeader->ih_name), "u-boot", strlen("U-Boot"));

	/* is this image is of DDR driver or actual firmware? */
	if (result1 != 0) {
		/* invalid image */
		printf("Firmware could not be downloaded. 4");
		fclose(fp);
		return 1;
	}

	/*
	 * Byte   0          :    Type of Data
	 * Byte   1 - 3      :    RESERVED
	 * Byte   4 - 7      :    Size of Data
	 * Byte   8 - 11     :    Load Address in RAM
	 */

	/* Sleep for 1 second before downloading Firmware */
	//sleep(1000);

	loadAddress = Conv_BigE_2_LittleE(pImageHeader->ih_load);
	imageSize = Conv_BigE_2_LittleE(pImageHeader->ih_size);

	sync_data[0] = FIRMWARE;

	sync_data[1] = 0;
	sync_data[2] = 0;
	sync_data[3] = 0;

	/* size of data */
	sync_data[4] = (imageSize & 0xff);
	sync_data[5] = ((imageSize >> 8) & 0xff);
	sync_data[6] = ((imageSize >> 16) & 0xff);
	sync_data[7] = ((imageSize >> 24) & 0xff);

	/* load address in SRAM where the data should be loaded => 0xD2801000*/
	sync_data[8] = (loadAddress & 0xff);
	sync_data[9] = ((loadAddress >> 8) & 0xff);
	sync_data[10] = ((loadAddress >> 16) & 0xff);
	sync_data[11] = ((loadAddress >> 24) & 0xff);

	if (SPEAr1340 == sprdev || SPEAr1310 == sprdev) {
		if(usb_bulk_write(usb_dev, EP_OUT, (char*)buf, IH_SIZE, 10000) != IH_SIZE) {
			printf("Firmware could not be downloaded.");
			exit(1);
		}
	} else {
		if(usb_bulk_write(usb_dev, EP_OUT, (char*)sync_data, 12, 10000)	!= 12) {
			printf("Firmware could not be downloaded.");
			exit(1);
		}
	}

	/* set transmit count to 0 */
	txCnt = 0;
	while (1) {
		readCnt = fread(buf, 1, NUM_OF_READ_DATA, fp);
		if (readCnt <= 0) {
			if (feof(fp) != 0) {
				/* end of file */
				fclose(fp);
				break;
			}
			if (ferror(fp) != 0) {
				printf("Error reading u-boot image file");
				exit(1);
			}
		}

		if(readCnt % 4)
			readCnt = (readCnt + 3) & ~3;

		if(usb_bulk_write(usb_dev, EP_OUT, (char*)buf, readCnt, 10000) !=  readCnt)
		{
			printf("Transmit failed 56");
			exit(1);
		}

		/* increment the transmit count if transmitted succesfully */
		txCnt += readCnt;
	}

	return 0; // return TRUE unless you set the focus to a control
}
