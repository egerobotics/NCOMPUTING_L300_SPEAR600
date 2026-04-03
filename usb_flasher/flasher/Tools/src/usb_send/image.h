/********************************************************************************
 *                  Copyright (C) 2006   STMicroelectronics                     *               
 *    Reproduction and Communication of this document is strictly prohibited    *
 *      unless specifically authorized in writing by STMicroelectronics.        *
 *                                                                              *
 * -------------------------------------------------------------------------    *
 *                                   CPG - CSD                                  *                                       
 *                                   SPEArPlus BootROM                          *                               
 *  ------------------------------------------------------------------------    *
 *                      Author - Ashwini Pahuja <ashwini.pahuja@st.com>         *                               
 *******************************************************************************/

#ifndef IMAGE_H_INCLUDE
#define IMAGE_H_INCLUDE


#define IH_NMLEN                32      /* Image Name Length */
#define IH_MAGIC			    0x27051956      /* Image Magic Number */

/* header of 64 bytes */
#define IH_SIZE					64

typedef  struct image_header {
        unsigned int        ih_magic;       /* Image Header Magic Number    */
        unsigned int        ih_hcrc;        /* Image Header CRC Checksum    */
        unsigned int        ih_time;        /* Image Creation Timestamp     */
        unsigned int        ih_size;        /* Image Data Size              */
        unsigned int        ih_load;        /* Data  Load  Address          */
        unsigned int        ih_ep;          /* Entry Point Address          */
        unsigned int        ih_dcrc;        /* Image Data CRC Checksum      */
        unsigned char       ih_os;          /* Operating System             */
        unsigned char       ih_arch;        /* CPU architecture             */
        unsigned char       ih_type;        /* Image Type                   */
        unsigned char       ih_comp;        /* Compression Type             */
        unsigned char       ih_name[IH_NMLEN];      /* Image Name           */
} image_header_t;


#endif

