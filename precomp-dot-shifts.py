#!/usr/bin/env python
#
# Pre-compiled dot code
#

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 256

DISPLAY_DOT_WIDTH = 4
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

        if self.__x < 0 or self.__x > SCREEN_WIDTH-DOT_PIXEL_WIDTH:
            output_file.write('; x clip\n')
            return

        if self.__y < 0 or self.__y > SCREEN_HEIGHT-DOT_PIXEL_HEIGHT:
            output_file.write('; y clip\n')
            return

        pixel_shift = self.__x % 4
        row_offset = self.__y % 8
        
        data00 = ((PIXEL_DATA_ROW_0 >> pixel_shift) & 0xf0) >> 4
        data01 = (PIXEL_DATA_ROW_0 >> pixel_shift) & 0x0f
        data10 = ((PIXEL_DATA_ROW_1 >> pixel_shift) & 0xf0) >> 4
        data11 = (PIXEL_DATA_ROW_1 >> pixel_shift) & 0x0f

        output_file.write('STA screen_ptr\n')
        output_file.write('STY screen_ptr+1\n')

        # Row 0

        if data00 != 0:
            output_file.write('LDY #' + str(row_offset) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data00 | data00<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        if data01 != 0:
            output_file.write('LDY #' + str(row_offset + 8) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data01 | data01<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        # Increment row

        if (row_offset == 7):
            output_file.write('CLC\n')
            output_file.write('LDA screen_ptr\n')
            output_file.write('ADC #LO(640)\n')
            output_file.write('STA screen_ptr\n')
            output_file.write('LDA screen_ptr+1\n')
            output_file.write('ADC #HI(640)\n')
            output_file.write('STA screen_ptr+1\n')
            row_offset = 0
        else:
            row_offset = row_offset + 1

        # Row 1

        if data10 != 0:
            output_file.write('LDY #' + str(row_offset) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data10 | data10<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        if data01 != 0:
            output_file.write('LDY #' + str(row_offset + 8) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data11 | data11<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        # Increment row

        if (row_offset == 7):
            output_file.write('CLC\n')
            output_file.write('LDA screen_ptr\n')
            output_file.write('ADC #LO(640)\n')
            output_file.write('STA screen_ptr\n')
            output_file.write('LDA screen_ptr+1\n')
            output_file.write('ADC #HI(640)\n')
            output_file.write('STA screen_ptr+1\n')
            row_offset = 0
        else:
            row_offset = row_offset + 1

        # Row 2

        if data10 != 0:
            output_file.write('LDY #' + str(row_offset) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data10 | data10<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        if data01 != 0:
            output_file.write('LDY #' + str(row_offset + 8) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data11 | data11<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        # Increment row

        if (row_offset == 7):
            output_file.write('CLC\n')
            output_file.write('LDA screen_ptr\n')
            output_file.write('ADC #LO(640)\n')
            output_file.write('STA screen_ptr\n')
            output_file.write('LDA screen_ptr+1\n')
            output_file.write('ADC #HI(640)\n')
            output_file.write('STA screen_ptr+1\n')
            row_offset = 0
        else:
            row_offset = row_offset + 1

        # Row 3

        if data00 != 0:
            output_file.write('LDY #' + str(row_offset) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data00 | data00<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

        if data01 != 0:
            output_file.write('LDY #' + str(row_offset + 8) + '\n')
            output_file.write('LDA #&' + '{:02X}'.format(data01 | data01<<4) + '\n')
            output_file.write('EOR (screen_ptr), Y\n')
            output_file.write('STA (screen_ptr), Y\n')

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

    for y in range(0,DISPLAY_DOT_HEIGHT):
        for x in range(0,DISPLAY_DOT_WIDTH):
            d = Dot()
            d.set_label('dot_'+'{:02d}{:02d}'.format(x,y))

            #x_norm = x / float(DISPLAY_DOT_WIDTH-1)
            #y_norm = y / float(DISPLAY_DOT_HEIGHT-1)
            #xy = calculate_xy(x_norm, y_norm)

            d.set_xy(x, y)
            dot_list.append(d)

    output_file = open(output_name, 'wt')

    print "Generating code for " + str(len(dot_list)) + " plot functions..."

    for d in dot_list:

        d.write_code(output_file)
        output_file.write('RTS\n')

    output_file.close()


if __name__ == '__main__':
    main()
