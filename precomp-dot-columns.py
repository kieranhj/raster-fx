#!/usr/bin/env python
#
# Pre-compiled dot code
#

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 256

TUNNEL_DOT_CIRCLE = 20
TUNNEL_DOT_LENGTH = 32

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

    def get_x(self):
        return self.__x

    def get_y(self):
        return self.__y

    def get_label(self):
        return self.__label

    def get_char_address(self):
        if self.__x < 0 or self.__x > SCREEN_WIDTH-DOT_PIXEL_WIDTH or self.__y < 0 or self.__y > SCREEN_HEIGHT-DOT_PIXEL_HEIGHT:
            print 'Clipping at x={:03d} y={:03d}'.format(self.__x, self.__y)
            return 0x3000 - 640*2 - 16

        return 0x3000 + (self.__y // 8) * 640 + (self.__x / 4) * 8

    def get_table_index(self):
        return (self.__y % 8) * 4 + self.__x % 4


def calculate_xy(x_norm, y_norm):
# Sine wave
    x_dot = x_norm * 310    #(SCREEN_WIDTH - DOT_PIXEL_WIDTH)
    y_dot = 64 * math.sin(2 * math.pi * x_norm) + (32 + 64 * x_norm) * y_norm

# Semi-circle
#    x_dot = 160 + (64 + 64 * y_norm) * math.sin(math.pi * x_norm - math.pi/2)
#    y_dot = 128 + (64 + 64 * y_norm) * math.cos(math.pi * x_norm - math.pi/2)

    # y_norm = angle around circle 0-1
    # x_norm = distance down the tunnel 0-1

    angle = y_norm * math.pi * 2
    radius = 64 + 192 * x_norm

    x_dot = math.sin(angle) * radius
    y_dot = math.cos(angle) * radius

    # Transform translate
    x_pos = x_dot + 160
    y_pos = y_dot + 128

    return [int(x_pos), int(y_pos)]


def main():
    if len(sys.argv) != 2:
        print "Syntax is: {} <assembler_source>".format(sys.argv[0])
        exit(0)

    output_name = sys.argv[1]
    
    dot_list = []

    for x in range(0,TUNNEL_DOT_LENGTH):
        for y in range(0,TUNNEL_DOT_CIRCLE):
            d = Dot()
            d.set_label('dot_'+'{:02d}{:02d}'.format(x,y))

            x_norm = x / float(TUNNEL_DOT_LENGTH-1)
            y_norm = y / float(TUNNEL_DOT_CIRCLE-1)

            xy = calculate_xy(x_norm, y_norm)

            d.set_xy(xy[0], xy[1])
            dot_list.append(d)


    output_file = open(output_name, 'wt')

    output_file.write('TUNNEL_DOT_CIRCLE=' + str(TUNNEL_DOT_CIRCLE) + '\n')
    output_file.write('TUNNEL_DOT_LENGTH=' + str(TUNNEL_DOT_LENGTH) + '\n')

    output_file.write('ALIGN &100\n')
    output_file.write('.dot_circle_table_LO\n')

    for x in range(0,TUNNEL_DOT_LENGTH):
        output_file.write('EQUB LO(dot_circle_' + str(x) + ')\n')

    output_file.write('.dot_circle_table_HI\n')

    for x in range(0,TUNNEL_DOT_LENGTH):
        output_file.write('EQUB HI(dot_circle_' + str(x) + ')\n')

    for x in range(0,TUNNEL_DOT_LENGTH):

        output_file.write('.dot_circle_' + str(x) + '\n')

        for y in range(0,TUNNEL_DOT_CIRCLE):
            d = dot_list[x * TUNNEL_DOT_CIRCLE + y]

            output_file.write('{\n')
            output_file.write('\t;x={:03d} y={:03d}\n'.format(d.get_x(),d.get_y()))
            output_file.write('\tLDA #LO(&{:04X}):LDY #HI(&{:04X}):'.format(d.get_char_address(),d.get_char_address()))
            output_file.write('JSR dot_{:02d}{:02d}\n'.format(d.get_table_index()%4,d.get_table_index()/4))
            output_file.write('}\n')

        output_file.write('RTS\n')

    output_file.close()


if __name__ == '__main__':
    main()
