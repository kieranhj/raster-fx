#!/usr/bin/env python
#
# Pre-compiled dot code
#

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 256

DISPLAY_DOT_WIDTH = 40
DISPLAY_DOT_HEIGHT = 8

DOT_PIXEL_WIDTH = 5
DOT_PIXEL_HEIGHT = 4

PIXEL_DATA_ROW_0 = 0b01110000
PIXEL_DATA_ROW_1 = 0b11111000

import sys
import math
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

    def get_label(self):
        return self.__label
    
    def write_code(self, output_file):

        output_file.write('.' + self.__label + '\t;x={:03d} y={:03d}\n'.format(self.__x,self.__y))

        if self.__x < 0 or self.__x >= SCREEN_WIDTH-DOT_PIXEL_WIDTH:
            output_file.write('; x clip\n')
            return

        if self.__y < 0 or self.__y >= SCREEN_HEIGHT-DOT_PIXEL_HEIGHT:
            output_file.write('; y clip\n')
            return

        row0_address = 0x3000 + (self.__y // 8) * 640 + (self.__y % 8) + (self.__x / 4) * 8
        row1_address = 0x3000 + ((self.__y+1) // 8) * 640 + ((self.__y+1) % 8) + (self.__x / 4) * 8
        row2_address = 0x3000 + ((self.__y+2) // 8) * 640 + ((self.__y+2) % 8) + (self.__x / 4) * 8
        row3_address = 0x3000 + ((self.__y+3) // 8) * 640 + ((self.__y+3) % 8) + (self.__x / 4) * 8
        pixel_shift = self.__x % 4
        
        data00 = ((PIXEL_DATA_ROW_0 >> pixel_shift) & 0xf0) >> 4
        data01 = (PIXEL_DATA_ROW_0 >> pixel_shift) & 0x0f
        data10 = ((PIXEL_DATA_ROW_1 >> pixel_shift) & 0xf0) >> 4
        data11 = (PIXEL_DATA_ROW_1 >> pixel_shift) & 0x0f

        if data00 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data00 | data00<<4) + '\n')      # AND dither_row0
            output_file.write('EOR &' + '{:04X}'.format(row0_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row0_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row3_address) + '\n')
            
        # could clip to rhs
        if data01 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data01 | data01<<4) + '\n')      # OR dither_row0
            output_file.write('EOR &' + '{:04X}'.format(row0_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row0_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row3_address + 8) + '\n')
        
        if data10 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data10 | data10<<4) + '\n')      # OR dither_row1
            output_file.write('EOR &' + '{:04X}'.format(row1_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row1_address) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row2_address) + '\n')

        if data11 != 0:
            output_file.write('LDA #&' + '{:02X}'.format(data11 | data11<<4) + '\n')      # OR dither_row1
            output_file.write('EOR &' + '{:04X}'.format(row1_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row1_address + 8) + '\n')
            output_file.write('STA &' + '{:04X}'.format(row2_address + 8) + '\n')

        #output_file.write('RTS\n')


def calculate_xy(x_norm, y_norm):
# Sine wave
    x_dot = x_norm * (SCREEN_WIDTH - DOT_PIXEL_WIDTH)
    y_dot = 64 * math.sin(2 * math.pi * x_norm) + (32 + 64 * x_norm) * y_norm

# Semi-circle
#    x_dot = 160 + (64 + 64 * y_norm) * math.sin(math.pi * x_norm - math.pi/2)
#    y_dot = 128 + (64 + 64 * y_norm) * math.cos(math.pi * x_norm - math.pi/2)

# Rectangle
#    x_dot = 256 * x_norm
#    y_dot = 64 * y_norm

    # Transform rotate
    angle = math.radians(0)
    x_pos = math.cos(angle) * x_dot - math.sin(angle) * y_dot
    y_pos = math.sin(angle) * x_dot + math.cos(angle) * y_dot

    # Transform translate
    x_pos = x_pos + 0
    y_pos = y_pos + 96

    return [int(x_pos), int(y_pos)]


def main():
    if len(sys.argv) != 2:
        print "Syntax is: {} <assembler_source>".format(sys.argv[0])
        exit(0)

    output_name = sys.argv[1]
    
    dot_list = []

    for x in range(0,DISPLAY_DOT_WIDTH):
        for y in range(0,DISPLAY_DOT_HEIGHT):
            d = Dot()
            d.set_label('dot_'+'{:02d}{:02d}'.format(x,y))

            x_norm = x / float(DISPLAY_DOT_WIDTH-1)
            y_norm = y / float(DISPLAY_DOT_HEIGHT-1)

            xy = calculate_xy(x_norm, y_norm)

            d.set_xy(xy[0], xy[1])
            dot_list.append(d)


    output_file = open(output_name, 'wt')

    output_file.write('DISPLAY_DOT_WIDTH=' + str(DISPLAY_DOT_WIDTH) + '\n')
    output_file.write('DISPLAY_DOT_HEIGHT=' + str(DISPLAY_DOT_HEIGHT) + '\n')

    output_file.write('.dot_table_LO\n')

    for x in range(0,DISPLAY_DOT_WIDTH):
        output_file.write('EQUB LO(dot_column_' + str(x) + ')\n')

    output_file.write('.dot_table_HI\n')

    for x in range(0,DISPLAY_DOT_WIDTH):
        output_file.write('EQUB HI(dot_column_' + str(x) + ')\n')

    for x in range(0,DISPLAY_DOT_WIDTH):

        output_file.write('.dot_column_' + str(x) + '\n')

        for y in range(0,DISPLAY_DOT_HEIGHT):
            d = dot_list[x * DISPLAY_DOT_HEIGHT + y]

            output_file.write('{\n')
            output_file.write('ROR data_byte\n')
            output_file.write('BCC skip_dot\n')
            d.write_code(output_file)
            output_file.write('.skip_dot\n')
            output_file.write('}\n')

        output_file.write('RTS\n')

    output_file.close()


if __name__ == '__main__':
    main()
