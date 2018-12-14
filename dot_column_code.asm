TUNNEL_DOT_CIRCLE=20
TUNNEL_DOT_LENGTH=32
ALIGN &100
.dot_circle_table_LO
EQUB LO(dot_circle_0)
EQUB LO(dot_circle_1)
EQUB LO(dot_circle_2)
EQUB LO(dot_circle_3)
EQUB LO(dot_circle_4)
EQUB LO(dot_circle_5)
EQUB LO(dot_circle_6)
EQUB LO(dot_circle_7)
EQUB LO(dot_circle_8)
EQUB LO(dot_circle_9)
EQUB LO(dot_circle_10)
EQUB LO(dot_circle_11)
EQUB LO(dot_circle_12)
EQUB LO(dot_circle_13)
EQUB LO(dot_circle_14)
EQUB LO(dot_circle_15)
EQUB LO(dot_circle_16)
EQUB LO(dot_circle_17)
EQUB LO(dot_circle_18)
EQUB LO(dot_circle_19)
EQUB LO(dot_circle_20)
EQUB LO(dot_circle_21)
EQUB LO(dot_circle_22)
EQUB LO(dot_circle_23)
EQUB LO(dot_circle_24)
EQUB LO(dot_circle_25)
EQUB LO(dot_circle_26)
EQUB LO(dot_circle_27)
EQUB LO(dot_circle_28)
EQUB LO(dot_circle_29)
EQUB LO(dot_circle_30)
EQUB LO(dot_circle_31)
.dot_circle_table_HI
EQUB HI(dot_circle_0)
EQUB HI(dot_circle_1)
EQUB HI(dot_circle_2)
EQUB HI(dot_circle_3)
EQUB HI(dot_circle_4)
EQUB HI(dot_circle_5)
EQUB HI(dot_circle_6)
EQUB HI(dot_circle_7)
EQUB HI(dot_circle_8)
EQUB HI(dot_circle_9)
EQUB HI(dot_circle_10)
EQUB HI(dot_circle_11)
EQUB HI(dot_circle_12)
EQUB HI(dot_circle_13)
EQUB HI(dot_circle_14)
EQUB HI(dot_circle_15)
EQUB HI(dot_circle_16)
EQUB HI(dot_circle_17)
EQUB HI(dot_circle_18)
EQUB HI(dot_circle_19)
EQUB HI(dot_circle_20)
EQUB HI(dot_circle_21)
EQUB HI(dot_circle_22)
EQUB HI(dot_circle_23)
EQUB HI(dot_circle_24)
EQUB HI(dot_circle_25)
EQUB HI(dot_circle_26)
EQUB HI(dot_circle_27)
EQUB HI(dot_circle_28)
EQUB HI(dot_circle_29)
EQUB HI(dot_circle_30)
EQUB HI(dot_circle_31)
.dot_circle_0
{
	;x=160 y=192
	LDA #LO(&6D40):LDY #HI(&6D40):JSR dot_0000
}
{
	;x=180 y=188
	LDA #LO(&6AE8):LDY #HI(&6AE8):JSR dot_0004
}
{
	;x=199 y=178
	LDA #LO(&6888):LDY #HI(&6888):JSR dot_0302
}
{
	;x=213 y=163
	LDA #LO(&63A8):LDY #HI(&63A8):JSR dot_0103
}
{
	;x=222 y=143
	LDA #LO(&5C38):LDY #HI(&5C38):JSR dot_0207
}
{
	;x=223 y=122
	LDA #LO(&5738):LDY #HI(&5738):JSR dot_0302
}
{
	;x=218 y=102
	LDA #LO(&4FB0):LDY #HI(&4FB0):JSR dot_0206
}
{
	;x=207 y=084
	LDA #LO(&4A98):LDY #HI(&4A98):JSR dot_0304
}
{
	;x=190 y=071
	LDA #LO(&4578):LDY #HI(&4578):JSR dot_0207
}
{
	;x=170 y=064
	LDA #LO(&4550):LDY #HI(&4550):JSR dot_0200
}
{
	;x=149 y=064
	LDA #LO(&4528):LDY #HI(&4528):JSR dot_0100
}
{
	;x=129 y=071
	LDA #LO(&4500):LDY #HI(&4500):JSR dot_0107
}
{
	;x=112 y=084
	LDA #LO(&49E0):LDY #HI(&49E0):JSR dot_0004
}
{
	;x=101 y=102
	LDA #LO(&4EC8):LDY #HI(&4EC8):JSR dot_0106
}
{
	;x=096 y=122
	LDA #LO(&5640):LDY #HI(&5640):JSR dot_0002
}
{
	;x=097 y=143
	LDA #LO(&5B40):LDY #HI(&5B40):JSR dot_0107
}
{
	;x=106 y=163
	LDA #LO(&62D0):LDY #HI(&62D0):JSR dot_0203
}
{
	;x=120 y=178
	LDA #LO(&67F0):LDY #HI(&67F0):JSR dot_0002
}
{
	;x=139 y=188
	LDA #LO(&6A90):LDY #HI(&6A90):JSR dot_0304
}
{
	;x=159 y=192
	LDA #LO(&6D38):LDY #HI(&6D38):JSR dot_0300
}
RTS
.dot_circle_1
{
	;x=160 y=198
	LDA #LO(&6D40):LDY #HI(&6D40):JSR dot_0006
}
{
	;x=182 y=194
	LDA #LO(&6D68):LDY #HI(&6D68):JSR dot_0202
}
{
	;x=203 y=183
	LDA #LO(&6890):LDY #HI(&6890):JSR dot_0307
}
{
	;x=218 y=166
	LDA #LO(&63B0):LDY #HI(&63B0):JSR dot_0206
}
{
	;x=228 y=145
	LDA #LO(&5EC8):LDY #HI(&5EC8):JSR dot_0001
}
{
	;x=229 y=122
	LDA #LO(&5748):LDY #HI(&5748):JSR dot_0102
}
{
	;x=224 y=099
	LDA #LO(&4FC0):LDY #HI(&4FC0):JSR dot_0003
}
{
	;x=211 y=080
	LDA #LO(&4AA0):LDY #HI(&4AA0):JSR dot_0300
}
{
	;x=193 y=066
	LDA #LO(&4580):LDY #HI(&4580):JSR dot_0102
}
{
	;x=171 y=058
	LDA #LO(&42D0):LDY #HI(&42D0):JSR dot_0302
}
{
	;x=148 y=058
	LDA #LO(&42A8):LDY #HI(&42A8):JSR dot_0002
}
{
	;x=126 y=066
	LDA #LO(&44F8):LDY #HI(&44F8):JSR dot_0202
}
{
	;x=108 y=080
	LDA #LO(&49D8):LDY #HI(&49D8):JSR dot_0000
}
{
	;x=095 y=099
	LDA #LO(&4EB8):LDY #HI(&4EB8):JSR dot_0303
}
{
	;x=090 y=122
	LDA #LO(&5630):LDY #HI(&5630):JSR dot_0202
}
{
	;x=091 y=145
	LDA #LO(&5DB0):LDY #HI(&5DB0):JSR dot_0301
}
{
	;x=101 y=166
	LDA #LO(&62C8):LDY #HI(&62C8):JSR dot_0106
}
{
	;x=116 y=183
	LDA #LO(&67E8):LDY #HI(&67E8):JSR dot_0007
}
{
	;x=137 y=194
	LDA #LO(&6D10):LDY #HI(&6D10):JSR dot_0102
}
{
	;x=159 y=198
	LDA #LO(&6D38):LDY #HI(&6D38):JSR dot_0306
}
RTS
.dot_circle_2
{
	;x=160 y=204
	LDA #LO(&6FC0):LDY #HI(&6FC0):JSR dot_0004
}
{
	;x=184 y=200
	LDA #LO(&6FF0):LDY #HI(&6FF0):JSR dot_0000
}
{
	;x=206 y=188
	LDA #LO(&6B18):LDY #HI(&6B18):JSR dot_0204
}
{
	;x=223 y=169
	LDA #LO(&6638):LDY #HI(&6638):JSR dot_0301
}
{
	;x=234 y=146
	LDA #LO(&5ED0):LDY #HI(&5ED0):JSR dot_0202
}
{
	;x=236 y=121
	LDA #LO(&5758):LDY #HI(&5758):JSR dot_0001
}
{
	;x=229 y=097
	LDA #LO(&4FC8):LDY #HI(&4FC8):JSR dot_0101
}
{
	;x=216 y=076
	LDA #LO(&4830):LDY #HI(&4830):JSR dot_0004
}
{
	;x=196 y=060
	LDA #LO(&4308):LDY #HI(&4308):JSR dot_0004
}
{
	;x=172 y=052
	LDA #LO(&4058):LDY #HI(&4058):JSR dot_0004
}
{
	;x=147 y=052
	LDA #LO(&4020):LDY #HI(&4020):JSR dot_0304
}
{
	;x=123 y=060
	LDA #LO(&4270):LDY #HI(&4270):JSR dot_0304
}
{
	;x=103 y=076
	LDA #LO(&4748):LDY #HI(&4748):JSR dot_0304
}
{
	;x=090 y=097
	LDA #LO(&4EB0):LDY #HI(&4EB0):JSR dot_0201
}
{
	;x=083 y=121
	LDA #LO(&5620):LDY #HI(&5620):JSR dot_0301
}
{
	;x=085 y=146
	LDA #LO(&5DA8):LDY #HI(&5DA8):JSR dot_0102
}
{
	;x=096 y=169
	LDA #LO(&6540):LDY #HI(&6540):JSR dot_0001
}
{
	;x=113 y=188
	LDA #LO(&6A60):LDY #HI(&6A60):JSR dot_0104
}
{
	;x=135 y=200
	LDA #LO(&6F88):LDY #HI(&6F88):JSR dot_0300
}
{
	;x=159 y=204
	LDA #LO(&6FB8):LDY #HI(&6FB8):JSR dot_0304
}
RTS
.dot_circle_3
{
	;x=160 y=210
	LDA #LO(&7240):LDY #HI(&7240):JSR dot_0002
}
{
	;x=186 y=206
	LDA #LO(&6FF0):LDY #HI(&6FF0):JSR dot_0206
}
{
	;x=210 y=193
	LDA #LO(&6DA0):LDY #HI(&6DA0):JSR dot_0201
}
{
	;x=229 y=173
	LDA #LO(&6648):LDY #HI(&6648):JSR dot_0105
}
{
	;x=240 y=148
	LDA #LO(&5EE0):LDY #HI(&5EE0):JSR dot_0004
}
{
	;x=242 y=121
	LDA #LO(&5760):LDY #HI(&5760):JSR dot_0201
}
{
	;x=235 y=094
	LDA #LO(&4D50):LDY #HI(&4D50):JSR dot_0306
}
{
	;x=220 y=072
	LDA #LO(&4838):LDY #HI(&4838):JSR dot_0000
}
{
	;x=199 y=055
	LDA #LO(&4088):LDY #HI(&4088):JSR dot_0307
}
{
	;x=173 y=046
	LDA #LO(&3DD8):LDY #HI(&3DD8):JSR dot_0106
}
{
	;x=146 y=046
	LDA #LO(&3DA0):LDY #HI(&3DA0):JSR dot_0206
}
{
	;x=120 y=055
	LDA #LO(&3FF0):LDY #HI(&3FF0):JSR dot_0007
}
{
	;x=099 y=072
	LDA #LO(&4740):LDY #HI(&4740):JSR dot_0300
}
{
	;x=084 y=094
	LDA #LO(&4C28):LDY #HI(&4C28):JSR dot_0006
}
{
	;x=077 y=121
	LDA #LO(&5618):LDY #HI(&5618):JSR dot_0101
}
{
	;x=079 y=148
	LDA #LO(&5D98):LDY #HI(&5D98):JSR dot_0304
}
{
	;x=090 y=173
	LDA #LO(&6530):LDY #HI(&6530):JSR dot_0205
}
{
	;x=109 y=193
	LDA #LO(&6CD8):LDY #HI(&6CD8):JSR dot_0101
}
{
	;x=133 y=206
	LDA #LO(&6F88):LDY #HI(&6F88):JSR dot_0106
}
{
	;x=159 y=210
	LDA #LO(&7238):LDY #HI(&7238):JSR dot_0302
}
RTS
.dot_circle_4
{
	;x=160 y=216
	LDA #LO(&74C0):LDY #HI(&74C0):JSR dot_0000
}
{
	;x=188 y=211
	LDA #LO(&7278):LDY #HI(&7278):JSR dot_0003
}
{
	;x=214 y=198
	LDA #LO(&6DA8):LDY #HI(&6DA8):JSR dot_0206
}
{
	;x=234 y=176
	LDA #LO(&68D0):LDY #HI(&68D0):JSR dot_0200
}
{
	;x=246 y=149
	LDA #LO(&5EE8):LDY #HI(&5EE8):JSR dot_0205
}
{
	;x=248 y=120
	LDA #LO(&5770):LDY #HI(&5770):JSR dot_0000
}
{
	;x=241 y=092
	LDA #LO(&4D60):LDY #HI(&4D60):JSR dot_0104
}
{
	;x=225 y=067
	LDA #LO(&45C0):LDY #HI(&45C0):JSR dot_0103
}
{
	;x=202 y=049
	LDA #LO(&4090):LDY #HI(&4090):JSR dot_0201
}
{
	;x=174 y=040
	LDA #LO(&3DD8):LDY #HI(&3DD8):JSR dot_0200
}
{
	;x=145 y=040
	LDA #LO(&3DA0):LDY #HI(&3DA0):JSR dot_0100
}
{
	;x=117 y=049
	LDA #LO(&3FE8):LDY #HI(&3FE8):JSR dot_0101
}
{
	;x=094 y=067
	LDA #LO(&44B8):LDY #HI(&44B8):JSR dot_0203
}
{
	;x=078 y=092
	LDA #LO(&4C18):LDY #HI(&4C18):JSR dot_0204
}
{
	;x=071 y=120
	LDA #LO(&5608):LDY #HI(&5608):JSR dot_0300
}
{
	;x=073 y=149
	LDA #LO(&5D90):LDY #HI(&5D90):JSR dot_0105
}
{
	;x=085 y=176
	LDA #LO(&67A8):LDY #HI(&67A8):JSR dot_0100
}
{
	;x=105 y=198
	LDA #LO(&6CD0):LDY #HI(&6CD0):JSR dot_0106
}
{
	;x=131 y=211
	LDA #LO(&7200):LDY #HI(&7200):JSR dot_0303
}
{
	;x=159 y=216
	LDA #LO(&74B8):LDY #HI(&74B8):JSR dot_0300
}
RTS
.dot_circle_5
{
	;x=160 y=222
	LDA #LO(&74C0):LDY #HI(&74C0):JSR dot_0006
}
{
	;x=190 y=217
	LDA #LO(&74F8):LDY #HI(&74F8):JSR dot_0201
}
{
	;x=218 y=202
	LDA #LO(&7030):LDY #HI(&7030):JSR dot_0202
}
{
	;x=239 y=179
	LDA #LO(&68D8):LDY #HI(&68D8):JSR dot_0303
}
{
	;x=252 y=151
	LDA #LO(&5EF8):LDY #HI(&5EF8):JSR dot_0007
}
{
	;x=254 y=120
	LDA #LO(&5778):LDY #HI(&5778):JSR dot_0200
}
{
	;x=246 y=089
	LDA #LO(&4D68):LDY #HI(&4D68):JSR dot_0201
}
{
	;x=229 y=063
	LDA #LO(&4348):LDY #HI(&4348):JSR dot_0107
}
{
	;x=205 y=044
	LDA #LO(&3E18):LDY #HI(&3E18):JSR dot_0104
}
{
	;x=175 y=034
	LDA #LO(&3B58):LDY #HI(&3B58):JSR dot_0302
}
{
	;x=144 y=034
	LDA #LO(&3B20):LDY #HI(&3B20):JSR dot_0002
}
{
	;x=114 y=044
	LDA #LO(&3D60):LDY #HI(&3D60):JSR dot_0204
}
{
	;x=090 y=063
	LDA #LO(&4230):LDY #HI(&4230):JSR dot_0207
}
{
	;x=073 y=089
	LDA #LO(&4C10):LDY #HI(&4C10):JSR dot_0101
}
{
	;x=065 y=120
	LDA #LO(&5600):LDY #HI(&5600):JSR dot_0100
}
{
	;x=067 y=151
	LDA #LO(&5D80):LDY #HI(&5D80):JSR dot_0307
}
{
	;x=080 y=179
	LDA #LO(&67A0):LDY #HI(&67A0):JSR dot_0003
}
{
	;x=101 y=202
	LDA #LO(&6F48):LDY #HI(&6F48):JSR dot_0102
}
{
	;x=129 y=217
	LDA #LO(&7480):LDY #HI(&7480):JSR dot_0101
}
{
	;x=159 y=222
	LDA #LO(&74B8):LDY #HI(&74B8):JSR dot_0306
}
RTS
.dot_circle_6
{
	;x=160 y=229
	LDA #LO(&7740):LDY #HI(&7740):JSR dot_0005
}
{
	;x=192 y=223
	LDA #LO(&7500):LDY #HI(&7500):JSR dot_0007
}
{
	;x=222 y=207
	LDA #LO(&7038):LDY #HI(&7038):JSR dot_0207
}
{
	;x=244 y=183
	LDA #LO(&68E8):LDY #HI(&68E8):JSR dot_0007
}
{
	;x=258 y=152
	LDA #LO(&6180):LDY #HI(&6180):JSR dot_0200
}
{
	;x=260 y=119
	LDA #LO(&5508):LDY #HI(&5508):JSR dot_0007
}
{
	;x=252 y=087
	LDA #LO(&4AF8):LDY #HI(&4AF8):JSR dot_0007
}
{
	;x=234 y=059
	LDA #LO(&4350):LDY #HI(&4350):JSR dot_0203
}
{
	;x=208 y=039
	LDA #LO(&3BA0):LDY #HI(&3BA0):JSR dot_0007
}
{
	;x=176 y=028
	LDA #LO(&38E0):LDY #HI(&38E0):JSR dot_0004
}
{
	;x=143 y=028
	LDA #LO(&3898):LDY #HI(&3898):JSR dot_0304
}
{
	;x=111 y=039
	LDA #LO(&3AD8):LDY #HI(&3AD8):JSR dot_0307
}
{
	;x=085 y=059
	LDA #LO(&4228):LDY #HI(&4228):JSR dot_0103
}
{
	;x=067 y=087
	LDA #LO(&4980):LDY #HI(&4980):JSR dot_0307
}
{
	;x=059 y=119
	LDA #LO(&5370):LDY #HI(&5370):JSR dot_0307
}
{
	;x=061 y=152
	LDA #LO(&5FF8):LDY #HI(&5FF8):JSR dot_0100
}
{
	;x=075 y=183
	LDA #LO(&6790):LDY #HI(&6790):JSR dot_0307
}
{
	;x=097 y=207
	LDA #LO(&6F40):LDY #HI(&6F40):JSR dot_0107
}
{
	;x=127 y=223
	LDA #LO(&7478):LDY #HI(&7478):JSR dot_0307
}
{
	;x=159 y=229
	LDA #LO(&7738):LDY #HI(&7738):JSR dot_0305
}
RTS
.dot_circle_7
{
	;x=160 y=235
	LDA #LO(&79C0):LDY #HI(&79C0):JSR dot_0003
}
{
	;x=194 y=229
	LDA #LO(&7780):LDY #HI(&7780):JSR dot_0205
}
{
	;x=225 y=212
	LDA #LO(&72C0):LDY #HI(&72C0):JSR dot_0104
}
{
	;x=249 y=186
	LDA #LO(&6B70):LDY #HI(&6B70):JSR dot_0102
}
{
	;x=264 y=154
	LDA #LO(&6190):LDY #HI(&6190):JSR dot_0002
}
{
	;x=266 y=119
	LDA #LO(&5510):LDY #HI(&5510):JSR dot_0207
}
{
	;x=258 y=084
	LDA #LO(&4B00):LDY #HI(&4B00):JSR dot_0204
}
{
	;x=238 y=055
	LDA #LO(&40D8):LDY #HI(&40D8):JSR dot_0207
}
{
	;x=211 y=033
	LDA #LO(&3BA0):LDY #HI(&3BA0):JSR dot_0301
}
{
	;x=177 y=022
	LDA #LO(&3660):LDY #HI(&3660):JSR dot_0106
}
{
	;x=142 y=022
	LDA #LO(&3618):LDY #HI(&3618):JSR dot_0206
}
{
	;x=108 y=033
	LDA #LO(&3AD8):LDY #HI(&3AD8):JSR dot_0001
}
{
	;x=081 y=055
	LDA #LO(&3FA0):LDY #HI(&3FA0):JSR dot_0107
}
{
	;x=061 y=084
	LDA #LO(&4978):LDY #HI(&4978):JSR dot_0104
}
{
	;x=053 y=119
	LDA #LO(&5368):LDY #HI(&5368):JSR dot_0107
}
{
	;x=055 y=154
	LDA #LO(&5FE8):LDY #HI(&5FE8):JSR dot_0302
}
{
	;x=070 y=186
	LDA #LO(&6A08):LDY #HI(&6A08):JSR dot_0202
}
{
	;x=094 y=212
	LDA #LO(&71B8):LDY #HI(&71B8):JSR dot_0204
}
{
	;x=125 y=229
	LDA #LO(&76F8):LDY #HI(&76F8):JSR dot_0105
}
{
	;x=159 y=235
	LDA #LO(&79B8):LDY #HI(&79B8):JSR dot_0303
}
RTS
.dot_circle_8
{
	;x=160 y=241
	LDA #LO(&7C40):LDY #HI(&7C40):JSR dot_0001
}
{
	;x=196 y=235
	LDA #LO(&7A08):LDY #HI(&7A08):JSR dot_0003
}
{
	;x=229 y=217
	LDA #LO(&7548):LDY #HI(&7548):JSR dot_0101
}
{
	;x=255 y=190
	LDA #LO(&6B78):LDY #HI(&6B78):JSR dot_0306
}
{
	;x=270 y=155
	LDA #LO(&6198):LDY #HI(&6198):JSR dot_0203
}
{
	;x=273 y=118
	LDA #LO(&5520):LDY #HI(&5520):JSR dot_0106
}
{
	;x=263 y=082
	LDA #LO(&4B08):LDY #HI(&4B08):JSR dot_0302
}
{
	;x=243 y=051
	LDA #LO(&40E0):LDY #HI(&40E0):JSR dot_0303
}
{
	;x=214 y=028
	LDA #LO(&3928):LDY #HI(&3928):JSR dot_0204
}
{
	;x=178 y=016
	LDA #LO(&3660):LDY #HI(&3660):JSR dot_0200
}
{
	;x=141 y=016
	LDA #LO(&3618):LDY #HI(&3618):JSR dot_0100
}
{
	;x=105 y=028
	LDA #LO(&3850):LDY #HI(&3850):JSR dot_0104
}
{
	;x=076 y=051
	LDA #LO(&3F98):LDY #HI(&3F98):JSR dot_0003
}
{
	;x=056 y=082
	LDA #LO(&4970):LDY #HI(&4970):JSR dot_0002
}
{
	;x=046 y=118
	LDA #LO(&5358):LDY #HI(&5358):JSR dot_0206
}
{
	;x=049 y=155
	LDA #LO(&5FE0):LDY #HI(&5FE0):JSR dot_0103
}
{
	;x=064 y=190
	LDA #LO(&6A00):LDY #HI(&6A00):JSR dot_0006
}
{
	;x=090 y=217
	LDA #LO(&7430):LDY #HI(&7430):JSR dot_0201
}
{
	;x=123 y=235
	LDA #LO(&7970):LDY #HI(&7970):JSR dot_0303
}
{
	;x=159 y=241
	LDA #LO(&7C38):LDY #HI(&7C38):JSR dot_0301
}
RTS
.dot_circle_9
{
	;x=160 y=247
	LDA #LO(&7C40):LDY #HI(&7C40):JSR dot_0007
}
{
	;x=198 y=241
	LDA #LO(&7C88):LDY #HI(&7C88):JSR dot_0201
}
{
	;x=233 y=222
	LDA #LO(&7550):LDY #HI(&7550):JSR dot_0106
}
{
	;x=260 y=193
	LDA #LO(&6E08):LDY #HI(&6E08):JSR dot_0001
}
{
	;x=276 y=157
	LDA #LO(&61A8):LDY #HI(&61A8):JSR dot_0005
}
{
	;x=279 y=118
	LDA #LO(&5528):LDY #HI(&5528):JSR dot_0306
}
{
	;x=269 y=079
	LDA #LO(&4898):LDY #HI(&4898):JSR dot_0107
}
{
	;x=248 y=046
	LDA #LO(&3E70):LDY #HI(&3E70):JSR dot_0006
}
{
	;x=216 y=022
	LDA #LO(&36B0):LDY #HI(&36B0):JSR dot_0006
}
{
	;x=179 y=009
	LDA #LO(&33E0):LDY #HI(&33E0):JSR dot_0301
}
{
	;x=140 y=009
	LDA #LO(&3398):LDY #HI(&3398):JSR dot_0001
}
{
	;x=103 y=022
	LDA #LO(&35C8):LDY #HI(&35C8):JSR dot_0306
}
{
	;x=071 y=046
	LDA #LO(&3D08):LDY #HI(&3D08):JSR dot_0306
}
{
	;x=050 y=079
	LDA #LO(&46E0):LDY #HI(&46E0):JSR dot_0207
}
{
	;x=040 y=118
	LDA #LO(&5350):LDY #HI(&5350):JSR dot_0006
}
{
	;x=043 y=157
	LDA #LO(&5FD0):LDY #HI(&5FD0):JSR dot_0305
}
{
	;x=059 y=193
	LDA #LO(&6C70):LDY #HI(&6C70):JSR dot_0301
}
{
	;x=086 y=222
	LDA #LO(&7428):LDY #HI(&7428):JSR dot_0206
}
{
	;x=121 y=241
	LDA #LO(&7BF0):LDY #HI(&7BF0):JSR dot_0101
}
{
	;x=159 y=247
	LDA #LO(&7C38):LDY #HI(&7C38):JSR dot_0307
}
RTS
.dot_circle_10
{
	;x=160 y=253
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=200 y=247
	LDA #LO(&7C90):LDY #HI(&7C90):JSR dot_0007
}
{
	;x=237 y=227
	LDA #LO(&77D8):LDY #HI(&77D8):JSR dot_0103
}
{
	;x=265 y=196
	LDA #LO(&6E10):LDY #HI(&6E10):JSR dot_0104
}
{
	;x=282 y=158
	LDA #LO(&61B0):LDY #HI(&61B0):JSR dot_0206
}
{
	;x=285 y=117
	LDA #LO(&5538):LDY #HI(&5538):JSR dot_0105
}
{
	;x=275 y=077
	LDA #LO(&48A0):LDY #HI(&48A0):JSR dot_0305
}
{
	;x=252 y=042
	LDA #LO(&3E78):LDY #HI(&3E78):JSR dot_0002
}
{
	;x=219 y=017
	LDA #LO(&36B0):LDY #HI(&36B0):JSR dot_0301
}
{
	;x=180 y=003
	LDA #LO(&3168):LDY #HI(&3168):JSR dot_0003
}
{
	;x=139 y=003
	LDA #LO(&3110):LDY #HI(&3110):JSR dot_0303
}
{
	;x=100 y=017
	LDA #LO(&35C8):LDY #HI(&35C8):JSR dot_0001
}
{
	;x=067 y=042
	LDA #LO(&3D00):LDY #HI(&3D00):JSR dot_0302
}
{
	;x=044 y=077
	LDA #LO(&46D8):LDY #HI(&46D8):JSR dot_0005
}
{
	;x=034 y=117
	LDA #LO(&5340):LDY #HI(&5340):JSR dot_0205
}
{
	;x=037 y=158
	LDA #LO(&5FC8):LDY #HI(&5FC8):JSR dot_0106
}
{
	;x=054 y=196
	LDA #LO(&6C68):LDY #HI(&6C68):JSR dot_0204
}
{
	;x=082 y=227
	LDA #LO(&76A0):LDY #HI(&76A0):JSR dot_0203
}
{
	;x=119 y=247
	LDA #LO(&7BE8):LDY #HI(&7BE8):JSR dot_0307
}
{
	;x=159 y=253
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
RTS
.dot_circle_11
{
	;x=160 y=260
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=202 y=252
	LDA #LO(&7F10):LDY #HI(&7F10):JSR dot_0204
}
{
	;x=241 y=232
	LDA #LO(&7A60):LDY #HI(&7A60):JSR dot_0100
}
{
	;x=270 y=200
	LDA #LO(&7098):LDY #HI(&7098):JSR dot_0200
}
{
	;x=288 y=160
	LDA #LO(&6440):LDY #HI(&6440):JSR dot_0000
}
{
	;x=291 y=117
	LDA #LO(&5540):LDY #HI(&5540):JSR dot_0305
}
{
	;x=281 y=074
	LDA #LO(&48B0):LDY #HI(&48B0):JSR dot_0102
}
{
	;x=257 y=038
	LDA #LO(&3C00):LDY #HI(&3C00):JSR dot_0106
}
{
	;x=222 y=011
	LDA #LO(&3438):LDY #HI(&3438):JSR dot_0203
}
{
	;x=181 y=-02
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=138 y=-02
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0206
}
{
	;x=097 y=011
	LDA #LO(&3340):LDY #HI(&3340):JSR dot_0103
}
{
	;x=062 y=038
	LDA #LO(&3A78):LDY #HI(&3A78):JSR dot_0206
}
{
	;x=038 y=074
	LDA #LO(&46C8):LDY #HI(&46C8):JSR dot_0202
}
{
	;x=028 y=117
	LDA #LO(&5338):LDY #HI(&5338):JSR dot_0005
}
{
	;x=031 y=160
	LDA #LO(&6238):LDY #HI(&6238):JSR dot_0300
}
{
	;x=049 y=200
	LDA #LO(&6EE0):LDY #HI(&6EE0):JSR dot_0100
}
{
	;x=078 y=232
	LDA #LO(&7918):LDY #HI(&7918):JSR dot_0200
}
{
	;x=117 y=252
	LDA #LO(&7E68):LDY #HI(&7E68):JSR dot_0104
}
{
	;x=159 y=260
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
RTS
.dot_circle_12
{
	;x=160 y=266
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=204 y=258
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=244 y=237
	LDA #LO(&7A68):LDY #HI(&7A68):JSR dot_0005
}
{
	;x=275 y=203
	LDA #LO(&70A0):LDY #HI(&70A0):JSR dot_0303
}
{
	;x=294 y=161
	LDA #LO(&6448):LDY #HI(&6448):JSR dot_0201
}
{
	;x=297 y=116
	LDA #LO(&5550):LDY #HI(&5550):JSR dot_0104
}
{
	;x=286 y=072
	LDA #LO(&48B8):LDY #HI(&48B8):JSR dot_0200
}
{
	;x=261 y=034
	LDA #LO(&3C08):LDY #HI(&3C08):JSR dot_0102
}
{
	;x=225 y=006
	LDA #LO(&31C0):LDY #HI(&31C0):JSR dot_0106
}
{
	;x=182 y=-08
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=137 y=-08
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=094 y=006
	LDA #LO(&30B8):LDY #HI(&30B8):JSR dot_0206
}
{
	;x=058 y=034
	LDA #LO(&3A70):LDY #HI(&3A70):JSR dot_0202
}
{
	;x=033 y=072
	LDA #LO(&46C0):LDY #HI(&46C0):JSR dot_0100
}
{
	;x=022 y=116
	LDA #LO(&5328):LDY #HI(&5328):JSR dot_0204
}
{
	;x=025 y=161
	LDA #LO(&6230):LDY #HI(&6230):JSR dot_0101
}
{
	;x=044 y=203
	LDA #LO(&6ED8):LDY #HI(&6ED8):JSR dot_0003
}
{
	;x=075 y=237
	LDA #LO(&7910):LDY #HI(&7910):JSR dot_0305
}
{
	;x=115 y=258
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=159 y=266
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
RTS
.dot_circle_13
{
	;x=160 y=272
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=206 y=264
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=248 y=242
	LDA #LO(&7CF0):LDY #HI(&7CF0):JSR dot_0002
}
{
	;x=280 y=207
	LDA #LO(&70B0):LDY #HI(&70B0):JSR dot_0007
}
{
	;x=300 y=163
	LDA #LO(&6458):LDY #HI(&6458):JSR dot_0003
}
{
	;x=304 y=116
	LDA #LO(&5560):LDY #HI(&5560):JSR dot_0004
}
{
	;x=292 y=069
	LDA #LO(&4648):LDY #HI(&4648):JSR dot_0005
}
{
	;x=266 y=030
	LDA #LO(&3990):LDY #HI(&3990):JSR dot_0206
}
{
	;x=228 y=000
	LDA #LO(&31C8):LDY #HI(&31C8):JSR dot_0000
}
{
	;x=183 y=-14
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=136 y=-14
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=091 y=000
	LDA #LO(&30B0):LDY #HI(&30B0):JSR dot_0300
}
{
	;x=053 y=030
	LDA #LO(&37E8):LDY #HI(&37E8):JSR dot_0106
}
{
	;x=027 y=069
	LDA #LO(&4430):LDY #HI(&4430):JSR dot_0305
}
{
	;x=015 y=116
	LDA #LO(&5318):LDY #HI(&5318):JSR dot_0304
}
{
	;x=019 y=163
	LDA #LO(&6220):LDY #HI(&6220):JSR dot_0303
}
{
	;x=039 y=207
	LDA #LO(&6EC8):LDY #HI(&6EC8):JSR dot_0307
}
{
	;x=071 y=242
	LDA #LO(&7B88):LDY #HI(&7B88):JSR dot_0302
}
{
	;x=113 y=264
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=159 y=272
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
RTS
.dot_circle_14
{
	;x=160 y=278
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=208 y=270
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=252 y=246
	LDA #LO(&7CF8):LDY #HI(&7CF8):JSR dot_0006
}
{
	;x=286 y=210
	LDA #LO(&7338):LDY #HI(&7338):JSR dot_0202
}
{
	;x=306 y=164
	LDA #LO(&6460):LDY #HI(&6460):JSR dot_0204
}
{
	;x=310 y=115
	LDA #LO(&5568):LDY #HI(&5568):JSR dot_0203
}
{
	;x=298 y=067
	LDA #LO(&4650):LDY #HI(&4650):JSR dot_0203
}
{
	;x=270 y=025
	LDA #LO(&3998):LDY #HI(&3998):JSR dot_0201
}
{
	;x=231 y=-04
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
{
	;x=184 y=-20
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=135 y=-20
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
{
	;x=088 y=-04
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=049 y=025
	LDA #LO(&37E0):LDY #HI(&37E0):JSR dot_0101
}
{
	;x=021 y=067
	LDA #LO(&4428):LDY #HI(&4428):JSR dot_0103
}
{
	;x=009 y=115
	LDA #LO(&5310):LDY #HI(&5310):JSR dot_0103
}
{
	;x=013 y=164
	LDA #LO(&6218):LDY #HI(&6218):JSR dot_0104
}
{
	;x=033 y=210
	LDA #LO(&7140):LDY #HI(&7140):JSR dot_0102
}
{
	;x=067 y=246
	LDA #LO(&7B80):LDY #HI(&7B80):JSR dot_0306
}
{
	;x=111 y=270
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=159 y=278
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
RTS
.dot_circle_15
{
	;x=160 y=284
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=210 y=276
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=256 y=251
	LDA #LO(&7F80):LDY #HI(&7F80):JSR dot_0003
}
{
	;x=291 y=213
	LDA #LO(&7340):LDY #HI(&7340):JSR dot_0305
}
{
	;x=312 y=166
	LDA #LO(&6470):LDY #HI(&6470):JSR dot_0006
}
{
	;x=316 y=115
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=303 y=064
	LDA #LO(&4658):LDY #HI(&4658):JSR dot_0300
}
{
	;x=275 y=021
	LDA #LO(&3720):LDY #HI(&3720):JSR dot_0305
}
{
	;x=234 y=-09
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=185 y=-26
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=134 y=-26
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0206
}
{
	;x=085 y=-09
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=044 y=021
	LDA #LO(&3558):LDY #HI(&3558):JSR dot_0005
}
{
	;x=016 y=064
	LDA #LO(&4420):LDY #HI(&4420):JSR dot_0000
}
{
	;x=003 y=115
	LDA #LO(&5300):LDY #HI(&5300):JSR dot_0303
}
{
	;x=007 y=166
	LDA #LO(&6208):LDY #HI(&6208):JSR dot_0306
}
{
	;x=028 y=213
	LDA #LO(&7138):LDY #HI(&7138):JSR dot_0005
}
{
	;x=063 y=251
	LDA #LO(&7DF8):LDY #HI(&7DF8):JSR dot_0303
}
{
	;x=109 y=276
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=159 y=284
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
RTS
.dot_circle_16
{
	;x=160 y=291
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=212 y=282
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=260 y=256
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=296 y=217
	LDA #LO(&75D0):LDY #HI(&75D0):JSR dot_0001
}
{
	;x=318 y=168
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=322 y=114
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=309 y=062
	LDA #LO(&43E8):LDY #HI(&43E8):JSR dot_0106
}
{
	;x=279 y=017
	LDA #LO(&3728):LDY #HI(&3728):JSR dot_0301
}
{
	;x=237 y=-15
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0101
}
{
	;x=186 y=-32
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=133 y=-32
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=082 y=-15
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=040 y=017
	LDA #LO(&3550):LDY #HI(&3550):JSR dot_0001
}
{
	;x=010 y=062
	LDA #LO(&4190):LDY #HI(&4190):JSR dot_0206
}
{
	;x=-02 y=114
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=001 y=168
	LDA #LO(&6480):LDY #HI(&6480):JSR dot_0100
}
{
	;x=023 y=217
	LDA #LO(&73A8):LDY #HI(&73A8):JSR dot_0301
}
{
	;x=059 y=256
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=107 y=282
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=159 y=291
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
RTS
.dot_circle_17
{
	;x=160 y=297
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=214 y=288
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=263 y=261
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
{
	;x=301 y=220
	LDA #LO(&75D8):LDY #HI(&75D8):JSR dot_0104
}
{
	;x=324 y=169
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=328 y=114
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=315 y=059
	LDA #LO(&43F0):LDY #HI(&43F0):JSR dot_0303
}
{
	;x=284 y=013
	LDA #LO(&34B8):LDY #HI(&34B8):JSR dot_0005
}
{
	;x=240 y=-20
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=187 y=-38
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=132 y=-38
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=079 y=-20
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
{
	;x=035 y=013
	LDA #LO(&32C0):LDY #HI(&32C0):JSR dot_0305
}
{
	;x=004 y=059
	LDA #LO(&4188):LDY #HI(&4188):JSR dot_0003
}
{
	;x=-08 y=114
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=-04 y=169
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=018 y=220
	LDA #LO(&73A0):LDY #HI(&73A0):JSR dot_0204
}
{
	;x=056 y=261
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=105 y=288
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=159 y=297
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
RTS
.dot_circle_18
{
	;x=160 y=303
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=216 y=293
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=267 y=266
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=306 y=223
	LDA #LO(&75E0):LDY #HI(&75E0):JSR dot_0207
}
{
	;x=330 y=171
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=334 y=113
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=320 y=057
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=289 y=009
	LDA #LO(&34C0):LDY #HI(&34C0):JSR dot_0101
}
{
	;x=243 y=-26
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=188 y=-45
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=131 y=-45
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
{
	;x=076 y=-26
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=030 y=009
	LDA #LO(&32B8):LDY #HI(&32B8):JSR dot_0201
}
{
	;x=000 y=057
	LDA #LO(&4180):LDY #HI(&4180):JSR dot_0001
}
{
	;x=-14 y=113
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=-10 y=171
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=013 y=223
	LDA #LO(&7398):LDY #HI(&7398):JSR dot_0107
}
{
	;x=052 y=266
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=103 y=293
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
{
	;x=159 y=303
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
RTS
.dot_circle_19
{
	;x=160 y=309
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=218 y=299
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=271 y=271
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=312 y=227
	LDA #LO(&7870):LDY #HI(&7870):JSR dot_0003
}
{
	;x=336 y=172
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=341 y=112
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=326 y=055
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=293 y=004
	LDA #LO(&3248):LDY #HI(&3248):JSR dot_0104
}
{
	;x=246 y=-31
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=189 y=-51
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=130 y=-51
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=073 y=-31
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0101
}
{
	;x=026 y=004
	LDA #LO(&3030):LDY #HI(&3030):JSR dot_0204
}
{
	;x=-06 y=055
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=-21 y=112
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=-16 y=172
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=007 y=227
	LDA #LO(&7608):LDY #HI(&7608):JSR dot_0303
}
{
	;x=048 y=271
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=101 y=299
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0103
}
{
	;x=159 y=309
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
RTS
.dot_circle_20
{
	;x=160 y=315
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=221 y=305
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0101
}
{
	;x=275 y=276
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
{
	;x=317 y=230
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=342 y=174
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0206
}
{
	;x=347 y=112
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=332 y=052
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=298 y=000
	LDA #LO(&3250):LDY #HI(&3250):JSR dot_0200
}
{
	;x=249 y=-37
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0103
}
{
	;x=190 y=-57
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=129 y=-57
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=070 y=-37
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=021 y=000
	LDA #LO(&3028):LDY #HI(&3028):JSR dot_0100
}
{
	;x=-12 y=052
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=-27 y=112
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=-22 y=174
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0206
}
{
	;x=002 y=230
	LDA #LO(&7600):LDY #HI(&7600):JSR dot_0206
}
{
	;x=044 y=276
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=098 y=305
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=159 y=315
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
RTS
.dot_circle_21
{
	;x=160 y=322
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=223 y=311
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=279 y=281
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
{
	;x=322 y=234
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=348 y=175
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=353 y=111
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=337 y=050
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0102
}
{
	;x=302 y=-03
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=252 y=-42
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=191 y=-63
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
{
	;x=128 y=-63
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=067 y=-42
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=017 y=-03
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=-17 y=050
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=-33 y=111
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=-28 y=175
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=-02 y=234
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=040 y=281
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=096 y=311
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=159 y=322
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
RTS
.dot_circle_22
{
	;x=160 y=328
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=225 y=317
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=283 y=286
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=327 y=237
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
{
	;x=354 y=177
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=359 y=111
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=343 y=047
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=307 y=-07
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
{
	;x=255 y=-48
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=192 y=-69
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=127 y=-69
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
{
	;x=064 y=-48
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=012 y=-07
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=-23 y=047
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=-39 y=111
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=-34 y=177
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=-07 y=237
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=036 y=286
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=094 y=317
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=159 y=328
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
RTS
.dot_circle_23
{
	;x=160 y=334
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=227 y=323
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
{
	;x=286 y=290
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=332 y=240
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=360 y=178
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=365 y=110
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=349 y=045
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=311 y=-11
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
{
	;x=258 y=-53
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=193 y=-75
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=126 y=-75
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=061 y=-53
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0103
}
{
	;x=008 y=-11
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=-29 y=045
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
{
	;x=-45 y=110
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=-40 y=178
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=-12 y=240
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=033 y=290
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0102
}
{
	;x=092 y=323
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=159 y=334
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
RTS
.dot_circle_24
{
	;x=160 y=340
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=229 y=329
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0101
}
{
	;x=290 y=295
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=338 y=244
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=366 y=180
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=371 y=110
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=354 y=042
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=316 y=-16
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=261 y=-59
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=195 y=-81
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=124 y=-81
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=058 y=-59
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=003 y=-16
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=-34 y=042
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=-51 y=110
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=-46 y=180
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=-18 y=244
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=029 y=295
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=090 y=329
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=159 y=340
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
RTS
.dot_circle_25
{
	;x=160 y=346
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=231 y=334
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=294 y=300
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=343 y=247
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=372 y=181
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=378 y=109
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=360 y=040
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=321 y=-20
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=264 y=-64
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=196 y=-87
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=123 y=-87
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
{
	;x=055 y=-64
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=-01 y=-20
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
{
	;x=-40 y=040
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=-58 y=109
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=-52 y=181
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=-23 y=247
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=025 y=300
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=088 y=334
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=159 y=346
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
RTS
.dot_circle_26
{
	;x=160 y=353
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=233 y=340
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=298 y=305
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=348 y=251
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=378 y=183
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=384 y=109
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=366 y=037
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=325 y=-24
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=267 y=-69
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
{
	;x=197 y=-93
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0103
}
{
	;x=122 y=-93
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=052 y=-69
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=-05 y=-24
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=-46 y=037
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=-64 y=109
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=-58 y=183
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=-28 y=251
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=021 y=305
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0101
}
{
	;x=086 y=340
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=159 y=353
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
RTS
.dot_circle_27
{
	;x=160 y=359
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0007
}
{
	;x=235 y=346
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=302 y=310
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0206
}
{
	;x=353 y=254
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=384 y=184
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=390 y=108
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=371 y=035
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
{
	;x=330 y=-28
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=270 y=-75
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=198 y=-100
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=121 y=-100
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=049 y=-75
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=-10 y=-28
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=-51 y=035
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0103
}
{
	;x=-70 y=108
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=-64 y=184
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=-33 y=254
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=017 y=310
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=084 y=346
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=159 y=359
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
RTS
.dot_circle_28
{
	;x=160 y=365
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0005
}
{
	;x=237 y=352
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=305 y=315
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0103
}
{
	;x=358 y=257
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=390 y=186
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=396 y=108
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=377 y=032
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=334 y=-32
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=272 y=-80
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=199 y=-106
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=120 y=-106
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=047 y=-80
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=-14 y=-32
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=-57 y=032
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=-76 y=108
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0004
}
{
	;x=-70 y=186
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=-38 y=257
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=014 y=315
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=082 y=352
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=159 y=365
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
RTS
.dot_circle_29
{
	;x=160 y=371
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=239 y=358
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=309 y=320
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=363 y=261
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0305
}
{
	;x=396 y=187
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=402 y=107
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=383 y=030
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0306
}
{
	;x=339 y=-36
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0304
}
{
	;x=275 y=-86
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=200 y=-112
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=119 y=-112
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=044 y=-86
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=-19 y=-36
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=-63 y=030
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0106
}
{
	;x=-82 y=107
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0203
}
{
	;x=-76 y=187
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=-43 y=261
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=010 y=320
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0200
}
{
	;x=080 y=358
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=159 y=371
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0303
}
RTS
.dot_circle_30
{
	;x=160 y=377
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0001
}
{
	;x=241 y=364
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=313 y=325
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=369 y=264
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0100
}
{
	;x=402 y=189
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=408 y=107
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=388 y=027
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=343 y=-41
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0307
}
{
	;x=278 y=-91
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=201 y=-118
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0102
}
{
	;x=118 y=-118
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=041 y=-91
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0105
}
{
	;x=-23 y=-41
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=-68 y=027
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=-88 y=107
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=-82 y=189
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=-49 y=264
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
{
	;x=006 y=325
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0205
}
{
	;x=078 y=364
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=159 y=377
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0301
}
RTS
.dot_circle_31
{
	;x=160 y=384
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0000
}
{
	;x=243 y=370
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=317 y=330
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0102
}
{
	;x=374 y=268
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=408 y=190
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=415 y=106
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0302
}
{
	;x=394 y=025
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=348 y=-45
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=281 y=-97
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0107
}
{
	;x=202 y=-124
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=117 y=-124
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0104
}
{
	;x=038 y=-97
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0207
}
{
	;x=-28 y=-45
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0003
}
{
	;x=-74 y=025
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0201
}
{
	;x=-95 y=106
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0102
}
{
	;x=-88 y=190
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0006
}
{
	;x=-54 y=268
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0204
}
{
	;x=002 y=330
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0202
}
{
	;x=076 y=370
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0002
}
{
	;x=159 y=384
	LDA #LO(&2AF0):LDY #HI(&2AF0):JSR dot_0300
}
RTS
