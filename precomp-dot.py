#!/usr/bin/env python
#
# Pre-compiled dot code
#

PIXEL_DATA_ROW_0 = 0b01110000
PIXEL_DATA_ROW_1 = 0b11111000

import sys
from os.path import basename

if (sys.version_info > (3, 0)):
	from io import BytesIO as ByteBuffer
else:
	from StringIO import StringIO as ByteBuffer

class Dot():

    def __init__(self):
        self.__x = 0        # x position
        self.__y = 0        # y position
        self.__label = 'nolabel'

    def set_xy(self, x, y):
        self.__x = x
        self.__y = y

    def set_label(self, label):
        self.__label = label 
    
    def write_code(self, output_file):

        output_file.write('.' + self.__label + '\n')

        row0_address = 0x3000 + (self.__y // 8) * 640 + (self.__y % 8) + (self.__x / 4) * 8
        row1_address = 0x3000 + ((self.__y+1) // 8) * 640 + ((self.__y+1) % 8) + (self.__x / 4) * 8
        row2_address = 0x3000 + ((self.__y+2) // 8) * 640 + ((self.__y+2) % 8) + (self.__x / 4) * 8

        pixel_shift = self.__x % 4
        
        data00 = ((PIXEL_DATA_ROW_0 >> pixel_shift) & 0xf0) >> 4
        data01 = (PIXEL_DATA_ROW_0 >> pixel_shift) & 0x0f
        data10 = ((PIXEL_DATA_ROW_1 >> pixel_shift) & 0xf0) >> 4
        data11 = (PIXEL_DATA_ROW_1 >> pixel_shift) & 0x0f

        if data00 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data00 | data00<<4) + '\n')      # AND dither_row0
            output_file.write('EOR &' + '{:04X}'.format(row0_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row0_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row2_address) + '\n')
            
        # could clip to rhs
        if data01 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data01 | data01<<4) + '\n')      # OR dither_row0
            output_file.write('EOR &' + '{:04X}'.format(row0_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row0_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row2_address + 8) + '\n')
        
        if data10 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data10 | data10<<4) + '\n')      # OR dither_row1
            output_file.write('EOR &' + '{:04X}'.format(row1_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row1_address) + '\n')

        if data11 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data11 | data11<<4) + '\n')      # OR dither_row1
            output_file.write('EOR &' + '{:04X}'.format(row1_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row1_address + 8) + '\n')

        output_file.write('RTS\n')

def main():
    if len(sys.argv) != 2:
        print "Syntax is: {} <assembler_source>".format(sys.argv[0])
        exit(0)

    output_name = sys.argv[1]
    
    a = Dot()
    b = Dot()
    c = Dot()
    d = Dot()

    a.set_xy(0,0)
    a.set_label('test1')

    b.set_xy(1,5)
    b.set_label('test2')

    c.set_xy(2,6)
    c.set_label('test3')

    d.set_xy(3,7)
    d.set_label('test4')

    output_file = open(output_name, 'wt')
    a.write_code(output_file)
    b.write_code(output_file)
    c.write_code(output_file)
    d.write_code(output_file)
    output_file.close()


if __name__ == '__main__':
    main()
