;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
; @kazenifukarete
;
; PCG-8100 routines for supporting graphic drawing
;
; 40colx25rows, Black and White mode,
; Emulate 320dot x 200 dot graphics
;
; 2024.05.03
;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

  ORG 0D000H

;
; DEF USR1=&hD000 : USR1(0)     : 'PCGの初期化
; DEF USR2=&hD003 : USR2(X%)    : 'X1座標のセット
; DEF USR3=&hD006 : USR3(Y%)    : 'Y1座標のセット
; DEF USR4=&hD009 : USR4(X2%)   : 'X2座標のセット
; DEF USR5=&hD00C : USR5(Y2%)   : 'Y2座標のセット&PSET
; DEF USR6=&HD00F : USR6(0|1|2) : 'PSET/PRESET/PXOR/BOXFILL実施
;                               : '   引数:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
;                               : '
;                               : '        4:BOX-PSET
;                               : '        5:BOX-PRESET
;                               : '        6:BOX-XOR
;                               : '        8:BOXFILL-PSET
;                               : '        9:BOXFILL-PRESET
;                               : '       10:BOXFILL-XOR
; DEF USR7=&HD012 : USR7(0|1|2) : '(X1,Y1)-(X2,Y2)にライン,BOX,BOXFILL を描画
;                               : '   引数:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
;                               : '
;                               : '        4:BOX-PSET
;                               : '        5:BOX-PRESET
;                               : '        6:BOX-XOR
;                               : '        8:BOXFILL-PSET
;                               : '        9:BOXFILL-PRESET
;                               : '       10:BOXFILL-XOR
; DEF USR8=&HD015 : USR8(0|1|2) ; '(X1,Y1)を中心に半径X2 の円を描く
;                               : '   引数:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
; DEF USR9=&HD018 : USR9(0)     ; 'バッファフラッシュ

  SYS_CLS EQU 45AH
  SYS_WIDTH EQU 843H
  SYS_CONSOLE EQU 884H
  SYS_CURSOR_OFF EQU 0BD2H
  BUF_MAX EQU 16  ; 128
  VRMDAT EQU 0675H ; VRAM LINE TOP ADDRESS DATA

; VSYNC後 331 x 36 =11916

ENTRY:
  JP   INIT_PCG
  JP   SET_X
  JP   SET_Y
  JP   SET_X2
  JP   SET_Y2
  JP   USR_PSET
  JP   LINE
  JP   MiechenerCircle
  JP   BUFFER_FLASH


INIT_PCG:                ; 画面モードを設定。40桁×25行、白黒
  CALL SYS_CLS
  LD   HL, WIDTH
  CALL SYS_WIDTH
  LD   HL, CONSOLE       ; 白黒モード
  CALL SYS_CONSOLE
  CALL SYS_CURSOR_OFF    ; カーソルクリア

CLS:                     ; 画面をクリア(PCGグラフィック向け)
  CALL CLEAR_PCG
;  CALL SET_ATTRIB
  CALL CLEAR_SCREEN
  LD   HL,BUFFER
  LD   (BUF_PTR),HL
  XOR  A
  LD   (NUM_BUF),A
  RET

;
; バッファに溜まった描画情報を吐き出す
;
BUFFER_CHECK:
  LD   A, (NUM_BUF)      ; バッファの空きを確認
  CP   BUF_MAX
  RET  C
BUFFER_FLASH:
  LD   A, (NUM_BUF)      ; バッファの空きを確認
  OR   A
  RET  Z
  LD   D, A
  LD   HL,BUFFER
  LD   (BUF_PTR),HL
  XOR  A
  LD   (NUM_BUF),A
  CALL VSYNC                   ; VSYNC待ち
BUFFER_FLASH_LOOP:
  LD   A,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  OUT  (0),A                   ; 11 clk
  LD   A,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  OUT  (1),A
  LD   A,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  OR   10H
  OUT  (2),A
  AND  0EFH
  OUT  (2),A
  DEC  D                       ;  4 clk
  JR   NZ, BUFFER_FLASH_LOOP   ; 12 clk : Total 91 clk
  RET


;
; X座標を設定
;

SET_X:
  LD   A,(HL)
  LD   (X_POS),A
  INC  HL
  LD   A,(HL)
  LD   (X_POS+1),A
  RET

;
; Y座標を設定
;

SET_Y:
  LD   A,(HL)
  LD   (Y_POS),A
  INC  HL
  LD   A,(HL)
  LD   (Y_POS+1),A
  RET

;
; X2座標を設定
;

SET_X2:
  LD   A,(HL)
  LD   (X2_POS),A
  INC  HL
  LD   A,(HL)
  LD   (X2_POS+1),A
  RET

;
; Y2座標を設定
;
SET_Y2:
  LD   A,(HL)
  LD   (Y2_POS),A
  INC  HL
  LD   A,(HL)
  LD   (Y2_POS+1),A
  RET

;
; BOXFILL の座標を画面内に戻す
;
TRIM_BOX:
  LD   HL,(X1_POS)    ; X1 < 0 → X1=0
  BIT  7,H
  JR   Z,TRIM_BOX_1
  LD   HL,0
  LD   (X1_POS),HL
TRIM_BOX_1:
  LD   DE,320         ; X1 >=320 → X1=319
  OR   A
  SBC  HL,DE
  JR   C,TRIM_BOX_2
  LD   HL,319
  LD   (X1_POS),HL
TRIM_BOX_2:
  LD   HL,(X2_POS)    ; X2 < 0 → X2 = 0
  BIT  7,H
  JR   Z,TRIM_BOX_3
  LD   HL,0
  LD   (X2_POS),HL
TRIM_BOX_3:
  LD   DE,320         ; X2 >=320 → X1=319
  OR   A
  SBC  HL,DE
  JR   C,TRIM_BOX_4
  LD   HL,319
  LD   (X2_POS),HL
TRIM_BOX_4:
  LD   HL,(Y1_POS)    ; Y1 < 0 → Y1=0
  BIT  7,H
  JR   Z,TRIM_BOX_5
  LD   HL,0
  LD   (Y1_POS),HL
TRIM_BOX_5:
  LD   DE,200         ; Y1 >=200 → Y1=199
  OR   A
  SBC  HL,DE
  JR   C,TRIM_BOX_6
  LD   HL,199
  LD   (Y1_POS),HL
TRIM_BOX_6:
  LD   HL,(Y2_POS)    ; Y2 < 0 → Y2=0
  BIT  7,H
  JR   Z,TRIM_BOX_7
  LD   HL,0
  LD   (Y2_POS),HL
TRIM_BOX_7:
  LD   DE,200         ; Y2 >=200 → Y2=199
  OR   A
  SBC  HL,DE
  RET  C
  LD   HL,199
  LD   (Y2_POS),HL
  RET

;
; BOX 系の座標の大小関係の整合性を取る
;
BOX_XY_SWAP:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, BOX_XY_SWAP1

  LD   HL,(X1_POS)
  LD   (X1_POS),DE
  LD   (X2_POS),HL

BOX_XY_SWAP1:
  LD   HL,(X1_POS)
  LD   (X_ORG),HL

  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  C

  LD   HL,(Y1_POS)
  LD   (Y1_POS),DE
  LD   (Y2_POS),HL

  RET


;
; BOXFILL
;
BOXFILL:
  CALL TRIM_BOX
  CALL BOX_XY_SWAP

BOXFILL_Y_LOOP:
  LD   HL,(X_ORG)
  LD   (X1_POS),HL
BOXFILL_X_LOOP:
  CALL BOXFILL_8DOT
  JR   NC,BOXFILL_X_LOOP_NEXT

  CALL CHECK_BUFFER_AND_PSET
  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL
BOXFILL_X_LOOP_NEXT:
  LD   DE,(X2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOXFILL_X_LOOP

  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  LD   DE,(Y2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOXFILL_Y_LOOP
  JP   BUFFER_FLASH



BOX:
  CALL BOX_XY_SWAP

BOX_Y_LOOP:
BOX_X0_LOOP:
  CALL BOXFILL_8DOT
  JR   NC,BOX_X0_LOOP_NEXT
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL

BOX_X0_LOOP_NEXT:
  LD   DE,(X2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOX_X0_LOOP

  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  LD   DE,(Y2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JP   C, BUFFER_FLASH     ; Y2 > Y1  なら終了
  JR   Z, BOX_FINAL_LOOP   ; Y2 == Y1 なら最終ライン描画へ

BOX_Y1_LOOP:
  LD   HL,(X_ORG)
  LD   (X1_POS),HL
  CALL CHECK_BUFFER_AND_PSET
  LD   HL,(X2_POS)
  LD   (X1_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JP   C, BOX_Y1_LOOP

BOX_FINAL_LOOP:
  LD   HL,(X_ORG)
  LD   (X1_POS),HL
BOX_X2_LOOP:
  CALL BOXFILL_8DOT
  JR   NC,BOX_X2_LOOP_NEXT

  CALL CHECK_BUFFER_AND_PSET
  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL
BOX_X2_LOOP_NEXT:
  LD   DE,(X2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOX_X2_LOOP
  JP   BUFFER_FLASH


;
; BOX FILL 高速化
;


BOXFILL_8DOT_NONE:
  SCF
  RET

BOXFILL_8DOT_DONE:
  LD   HL,(X1_POS)
  LD   A,8
  ADD  A,L
  LD   L,A
  JR   NC, BOXFILL_8DOT_DONE_FIN
  INC  H
BOXFILL_8DOT_DONE_FIN:
  LD   (X1_POS),HL
  OR   A
  RET

BOXFILL_8DOT:
  LD  HL,(X_POS)
  LD  A,L                   ; 8の倍数以外の場所では return
  AND 7
  JR  NZ,BOXFILL_8DOT_NONE
  LD  DE,312
  SBC HL,DE
  JR  NC,BOXFILL_8DOT_NONE  ; 312以上ではret

  LD   HL,(X2_POS)
  LD   DE,(X_POS)
  OR   A
  SBC  HL,DE
  OR   A
  LD   DE,7
  SBC  HL,DE
  JR   C,BOXFILL_8DOT_NONE  ; 描画必要長が8ピクセル以下ならret

  LD   A,(PRESET_FLAG)
  DEC  A
  JP   Z, BOXFILL_8DOT_PRESET_XY
  DEC  A
  JP   Z, BOXFILL_8DOT_XOR    ; XOR に分岐

  CALL CALC_ADR               ; 指定座標に文字があるか確認
  BIT  7,A
  JR   NZ,BOXFILL_8DOT_CH_NO  ; 文字があった場合は、当該文字にドットを追加

  CALL SEARCH_NEXT           ; ブロック内の未使用文字コードを抽出
  JR   Z,BOXFILL_8DOT_NONE   ; 未使用文字なし
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)         ; 未使用文字をVRAMに登録
  LD   (HL),A

BOXFILL_8DOT_CH_NO:          ; CH_NO にドットを追加する
  CALL BUFFER_CHECK
  CALL CALC_PCG_RAM_ADR

;  LD   (PCG_RAM_ADDR),HL    ; この処理不要？

  LD   A,255                 ; PCG RAM にビットパタンをANDする
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER
  JP   BOXFILL_8DOT_DONE


BOXFILL_8DOT_PRESET_XY:
  CALL CALC_ADR              ; 指定座標に文字があるか確認
  BIT  7,A
  JP   Z,BOXFILL_8DOT_DONE   ; 文字が無い場合は何もしない

BOXFILL_8DOT_PRESET_CH_NO:   ; CH_NO のドットをクリアする
  CALL BUFFER_CHECK
  CALL CALC_PCG_RAM_ADR
;  LD   (PCG_RAM_ADDR),HL   ; この処理不要？


  LD   A,0                ; PCG RAM に空白ビットパタンを入れる
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER


CHECK_EMPTY_CHAR_BOXFILL_8DOT:
  CALL CHECK_EMPTY_CHAR
  JP   BOXFILL_8DOT_DONE



BOXFILL_8DOT_XOR:
  CALL CALC_ADR               ; 指定座標に文字があるか確認
  BIT  7,A
  JR   NZ,BOXFILL_8DOT_XOR_CH_NO   ; 文字があった場合は、当該文字にドットを追加

  CALL SEARCH_NEXT         ; ブロック内の未使用文字コードを抽出
  JP   Z,BOXFILL_8DOT_NONE ; 未使用文字なし
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)       ; 未使用文字をVRAMに登録
  LD   (HL),A

BOXFILL_8DOT_XOR_CH_NO:    ; CH_NO にドットを追加する
  CALL BUFFER_CHECK
  CALL CALC_PCG_RAM_ADR

;  LD   (PCG_RAM_ADDR),HL   ; この処理不要？

  LD   A,255                ; PCG RAM にビットパタンをANDする
  XOR  (HL)
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER

  LD   A,(HL)
  OR   A
  JP   NZ,BOXFILL_8DOT_DONE   ; 書き込み値が0以外の時はチェック不要
  JP   CHECK_EMPTY_CHAR_BOXFILL_8DOT


CALC_PCG_RAM_ADR:
  LD   HL,PCG_RAM
  LD   A,(CH_NO)             ; (CH_NO)*8 を HLに加える
  AND  7FH
  LD   D,0
  ADD  A,A
  RL   D
  ADD  A,A
  RL   D
  ADD  A,A
  RL   D
  LD   E,A
  ADD  HL,DE

  LD   (PCG_CH_TOP),HL       ; PCGの文字パタントップのアドレス保存

  LD   A,(Y_POS)             ; (Y_POS) AND 7をHLに加える
  AND  7
  LD   C,A                   ; この値は、OUT (C),A まで変えない
  ADD  A,L
  LD   L,A
  RET  NC
  INC  H
  RET


STORE_PCG_DATA_TO_BUFFER:    ; HL は PCG_RAM の当該パタンを指す
  LD   DE,(BUF_PTR)

  LD   A,(HL)                ; PCG書き込みパタンを用意
  LD   (DE),A
  INC  DE

  PUSH DE
  LD   DE, PCG_RAM
  OR   A
  SBC  HL,DE
  POP  DE

  LD   A,L
  LD   (DE),A
  INC  DE

  LD   A,H
  LD   (DE),A
  INC  DE

  LD   (BUF_PTR),DE
  LD   A,(NUM_BUF)
  INC  A
  LD   (NUM_BUF),A
  RET


USR_PSET:
  LD  A,(HL)
  AND 3
  LD  (PRESET_FLAG),A
  LD  A,(HL)
  AND 12
  CP  4
  JP  Z, BOX
  CP  8
  JP  Z, BOXFILL

CHECK_BUFFER_AND_PSET:
  LD   A,(NUM_BUF)        ; プロットバッファが満杯かチェック
  CP   BUF_MAX
  JR   C,PSET_XY          ; プロットバッファに空きあり
  CALL BUFFER_FLASH       ; プロットバッファをフラッシュ

PSET_XY:
  LD   HL,(X_POS)         ; 0 <= X_POS < 320 チェック
  BIT  7,H
  RET  NZ
  LD   DE,320
  OR   A
  SBC  HL,DE              ; >= 320 ならばRET
  RET  NC
  LD   HL,(Y_POS)         ; 0 <= Y_POS < 200 チェック
  BIT  7,H                ; 負の値ならば、RET
  RET  NZ
  LD   DE,200
  OR   A
  SBC  HL,DE              ; >= 200 ならばRET
  RET  NC

  LD   A,(PRESET_FLAG)
  DEC  A
  JP   Z, PRESET_XY
  DEC  A
  JP   Z,PXOR_XY          ; PRESET に分岐

  CALL CALC_ADR           ; 指定座標に文字があるか確認
  BIT  7,A
  JR   NZ,PSET_CH_NO      ; 文字があった場合は、当該文字にドットを追加

  CALL SEARCH_NEXT        ; ブロック内の未使用文字コードを抽出
  RET  Z                  ; 未使用文字なし
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; 未使用文字をVRAMに登録
  LD   (HL),A

PSET_CH_NO:               ; CH_NO にドットを追加する
  CALL CALC_PCG_RAM_ADR    ; PCG RAM アドレス計算

;  LD   (PCG_RAM_ADDR),HL  ; この処理不要？
  LD   A,(X_POS)           ; (X_POS)からビットパタンを計算
  AND  7
  LD   B,A
  LD   A,80H
  JR   Z,SHIFTED
SHIFT_LOOP:
  RRCA
  DJNZ SHIFT_LOOP
SHIFTED:

  OR   (HL)                 ; PCG RAM にビットパタンをORする
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER
  RET

PXOR_XY:
  CALL CALC_ADR           ; 指定座標に文字があるか確認
  BIT  7,A
  JR   NZ,XOR_CH_NO       ; 文字があった場合は、当該文字にドットをXOR

  CALL SEARCH_NEXT        ; ブロック内の未使用文字コードを抽出
  RET  Z                  ; 未使用文字なし
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; 未使用文字をVRAMに登録
  LD   (HL),A

XOR_CH_NO:                ; CH_NO にドットをXORする
  CALL CALC_PCG_RAM_ADR    ; PCG RAM アドレス計算
;  LD   (PCG_RAM_ADDR),HL   ; この処理不要？
  LD   A,(X_POS)           ; (X_POS)からビットパタンを計算
  AND  7
  LD   B,A
  LD   A,80H
  JR   Z,SHIFTED_XOR
SHIFT_LOOP_XOR:
  RRCA
  DJNZ SHIFT_LOOP_XOR
SHIFTED_XOR:

  XOR  (HL)                 ; PCG RAM にビットパタンをANDする
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER

  LD   A,(HL)
  OR   A
  RET  NZ

  JP   CHECK_EMPTY_CHAR

;
; ブロック内の未使用文字コードを探し(CH_NO)に入れる。
; これが 0 なら、もう割り当てられるコードは存在しない
;

SEARCH_NEXT:
  LD   A,(NUM_UNUSED)
  OR   A
  JR   Z,EMPTY_NOT_FOUND
  DEC  A
  LD   (NUM_UNUSED),A

  LD   HL,CHAR_USED

  LD   D,128
  LD   B,128
SEARCH_LOOP:
  LD   A,(HL)
  OR   A
  JR   Z,EMPTY_CHAR_FOUND
  INC  HL
  INC  D
  DJNZ SEARCH_LOOP

  XOR  A             ; 空いているキャラクタが見つからなかった
EMPTY_NOT_FOUND:
  LD   (CH_NO),A
  RET

EMPTY_CHAR_FOUND:
  LD   A,D
  LD   (HL),A        ; 非ゼロの値が入っているので、フラグ代わりに用いる
  LD   (CH_NO),A
  OR   A
  RET

;
; Ｙ座標からブロック番号に変換し、(BLK)に格納
;
;CHK_BLK:
;  LD   A,(Y_POS)
;  SRL  A          ; A=A/64
;  RLCA
;  RLCA
;  AND  3
;  LD   (BLK),A
;  RET

;
; (X_POS),(Y_POS)から、VRAMアドレスを計算
;
CALC_ADR:
  LD   HL,VRMDAT
  LD   A,(Y_POS)
  RRCA              ; A=A/4
  RRCA
  AND  31*2
  ADD  A,L
  LD   L,A
  LD   E,(HL)
  INC  HL
  LD   D,(HL)
  EX   DE,HL
  LD   A,(X_POS+1)
  LD   B, A
  LD   A,(X_POS)
  SRL  B
  RRA
  SRL  B
  RRA
  AND  0FEH
  ADD  A,L
  LD   L,A
  JR   NC, CALC_ADR_NO_CARRY
  INC  H
CALC_ADR_NO_CARRY:
  LD   (VRAM_ADR),HL
  LD   A,(HL)
  LD   (CH_NO),A
  OR   A
  RET


PRESET_XY:
PRESET_XY_SUB:
  CALL CALC_ADR           ; 指定座標に文字があるか確認
  BIT  7,A
  RET  Z                  ; 指定座標に文字がなければ終了

PRESET_CH_NO:             ; CH_NO のドットを削減する
  CALL CALC_PCG_RAM_ADR   ; PCG RAM アドレス計算

  LD   A,(X_POS)          ; (X_POS)からビットパタンを計算
  AND  7
  LD   B,A
  LD   A,7FH
  JR   Z,SHIFTED_PRESET
SHIFT_LOOP_PRESET:
  RRCA
  DJNZ SHIFT_LOOP_PRESET
SHIFTED_PRESET:

  AND  (HL)               ; PCG RAM にビットパタンをANDする
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER

  LD   A,(HL)
  OR   A                  ; PCGパタンが0でなければ、終了
  RET  NZ

; ここから、PCGのパタンがAll 0でないかのチェック
CHECK_EMPTY_CHAR:

  LD   HL, (PCG_CH_TOP)

  LD   A,(HL)    ; 0
  INC  HL
  OR   (HL)      ; 1
  INC  HL
  OR   (HL)      ; 2
  INC  HL
  OR   (HL)      ; 3
  INC  HL
  OR   (HL)      ; 4
  INC  HL
  OR   (HL)      ; 5
  INC  HL
  OR   (HL)      ; 6
  INC  HL
  OR   (HL)      ; 7
  RET  NZ        ; All 0 ではない

  LD   A,0
  LD   HL,(VRAM_ADR)
  LD   (HL),A    ; VRAM上のキャラをクリア

  LD   HL,CHAR_USED
  LD   A,(CH_NO)
  AND  7FH
  ADD  A,L
  LD   L,A
  JR   NC, NO_CARRY_CLEAR_USED
  INC  H
NO_CARRY_CLEAR_USED:
  LD   A,(NUM_UNUSED)
  INC  A
  LD   (NUM_UNUSED),A
  XOR  A
  LD   (HL),A
  RET


;
; 垂直帰線期間待ち
; Aレジスタは破壊される
;

VSYNC:
;  PUSH AF
VSYNC_0:
  IN   A,(40H)
  AND  20H
  JR   NZ,VSYNC_0
VSYNC_1:
  IN   A,(40H)
  AND  20H
  JR   Z,VSYNC_1
;  POP  AF
  RET

;
; V-RAMをクリア
;

CLEAR_SCREEN:
  LD   HL,0F300H
  LD   C,25
;
; 1行目から24行目の処理
;
CLEAR_SCREEN_Y_LOOP:
  LD   B,40
  XOR  A
CLEAR_SCREEN_X_LOOP:
  LD   (HL),A
  INC  HL
  INC  HL
  DJNZ CLEAR_SCREEN_X_LOOP
  LD   A,40
  ADD  A,L
  LD   L,A
  JR   NC, CEAR_SCREEN_X_FIN
  INC  H
CEAR_SCREEN_X_FIN:
  DEC  C
  JR   NZ, CLEAR_SCREEN_Y_LOOP
  RET

;
; V-RAMアトリビュートを反転に設定
;

;SET_ATTRIB:
;  LD  DE,0F350H
;  LD  B,25
;
;SET_ATTRIB_LOOP:
;  PUSH BC
;  LD   BC, 4
;  LD   HL, ATTRIB_DATA
;  LDIR
;  LD   HL,120-4
;  ADD  HL,DE
;  LD   D,H
;  LD   E,L
;  POP  BC
;  DJNZ SET_ATTRIB_LOOP
;  RET

;
; PCGのRAMバッファとPCGの登録を全クリアする
;

CLEAR_PCG:
  CALL CLEAR_CHAR_USED
  LD   HL,PCG_RAM
  LD   BC,128*8
CLEAR_PCG_0:
  XOR  A
  LD   (HL),A
  INC  HL
  DEC  BC
  LD   A,B
  OR   C
  JR   NZ,CLEAR_PCG_0


  LD   DE,0

  LD   B,16
  LD   C,2
  XOR  A
  OUT  (0),A

CLEAR_PCG_256_LOOP:
  LD   H,8
  CALL VSYNC
CLEAR_PCG_8_LOOP
  CALL CLEAR_1CH_PCG         ; 165 clk
  DEC  H
  JR   NZ, CLEAR_PCG_8_LOOP
  DJNZ CLEAR_PCG_256_LOOP
  RET

;
; PCG１キャラ分クリア
;

CLEAR_1CH_PCG:
;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

;  XOR  A
;  OUT  (0),A
  LD   A,E
  OUT  (1),A
  LD   A,D
  OR   10H
  OUT  (C),A
  LD   A,D
  OUT  (C),A
  INC  DE

  RET                        ; 10 clk : Total 145 clk


CLEAR_CHAR_USED:
  LD   HL,CHAR_USED
  XOR  A
  LD   B,128
CLEAR_CHAR_USED_SUB_1:
  LD   (HL),A
  INC  HL
  DJNZ CLEAR_CHAR_USED_SUB_1
  LD   A,128
  LD   (NUM_UNUSED),A
  RET


WIDTH DB "40,25",0
CONSOLE DB "0,25,0,0",0
ATTRIB_DATA DB 0,4,80,0

;
;
; CIRCLE
;
; https://dencha.ojaru.jp/programs_07/pg_graphic_09a1.html
;
MiechenerCircle:
  LD  A,(HL)
  AND 3
  LD  (PRESET_FLAG),A

  LD   DE,(Radius)
  LD   A,D                       ; 半径が0の時は、１点だけプロットする
  OR   E
  JP   Z,CHECK_BUFFER_AND_PSET

  LD   (cy), DE
  LD   HL,3
  OR   A
  SBC  HL,DE
  OR   A
  SBC  HL,DE
  LD   (M_d),HL

  LD   HL,(X_POS)
  LD   (center_x),HL

  LD   HL,(Y_POS)
  LD   (center_y),HL

  LD   DE,(Radius)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_y)
  LD   DE,(Radius)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET


  LD   HL,(center_y)
  LD   (Y_POS),HL
  LD   HL,(center_x)
  LD   DE,(Radius)
  ADD  HL,DE
  LD   (X_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_y)
  LD   (Y_POS),HL
  LD   HL,(center_x)
  LD   DE,(Radius)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,0
  LD   (cx),HL
for_cx_loop:
  LD   HL,(cx)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  JR   Z, for_cx_body
  JR   C, for_cx_body
  JP   BUFFER_FLASH

for_cx_body:
  LD   HL,(cx)      ; DE = 4*cx
  ADD  HL,HL
  ADD  HL,HL
  EX   DE,HL
  LD   HL,(cy)      ; BC = 4*cy
  ADD  HL,HL
  ADD  HL,HL
  LD   B,H
  LD   C,L

  LD   HL,(M_d)
  BIT  7,H
  JR   Z, for_cx_plus
  ADD  HL,DE
  LD   DE,6
  ADD  HL,DE
  LD   (M_d),HL
  JR   for_cx_body2

for_cx_plus:
  ADD  HL,DE
  OR   A
  SBC  HL,BC
  LD   DE,10
  ADD  HL,DE
  LD   (M_d),HL
  LD   DE,(cy)
  DEC  DE
  LD   (cy),DE

for_cx_body2:

  ;    同じ所を２回プロットしないようにチェック
  ;
  LD   HL,(cx)
  LD   DE,(cy)
  OR   A
  SBC  HL, DE
  JR   Z,  circle_half
  JP   NC, BUFFER_FLASH

  LD   HL,(center_x)
;  LD   DE,(cy)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 0-45

  LD   HL,(center_x)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 90-135

  LD   HL,(center_x)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 180-225

  LD   HL,(center_x)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 270-315


circle_half:

  LD   HL,(center_x)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 45-90

  LD   HL,(center_x)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 135-180

  LD   HL,(center_x)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 225-270

  LD   HL,(center_x)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 315-360

circle_skip:

  LD   HL,(cx)
  INC  HL
  LD   (cx),HL
  JP   for_cx_loop

;
; (X1,Y1)と(X2,Y2)を交換する
;

SWAP_X1Y1_X2Y2:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  LD   (X1_POS),DE
  LD   (X2_POS),HL

  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  LD   (Y1_POS),DE
  LD   (Y2_POS),HL
  RET


NEG_HL:
  PUSH DE
  LD   DE,0
  EX   DE,HL
  OR   A
  SBC  HL,DE
  POP  DE
  RET

LINE:
  LD A,(HL)
  AND 3
  LD  (PRESET_FLAG),A
  LD  A,(HL)
  AND 12
  CP  4
  JP  Z, BOX
  CP  8
  JP  Z, BOXFILL

CALC_DXDY:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   NC,CALC_DXDY_X
  CALL NEG_HL
CALC_DXDY_X:
  LD   (dx),HL
  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   NC,CALC_DXDY_Y
  CALL NEG_HL
CALC_DXDY_Y:
  LD   (dy),HL

  LD   A,(dx)
  LD   B,A
  LD   A,(dx+1)
  OR   B
  JR   Z, LINE_vertical

  LD   A,(dy)
  LD   B,A
  LD   A,(dy+1)
  OR   B
  JR   Z, LINE_horizontal

  LD   HL,(dx)
  LD   DE,(dy)
  OR   A
  SBC  HL,DE
  JP   C, LINE_y_base
  JP   LINE_x_base

;
; 縦線を描く
;

LINE_vertical:
  LD   A,(dy)
  LD   B,A
  LD   A,(dy+1)
  OR   B
  JP   Z, CHECK_BUFFER_AND_PSET

  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_vertical_start
  CALL SWAP_X1Y1_X2Y2
LINE_vertical_start:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(Y1_POS)
  LD   HL,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (Y1_POS),DE
  JR   LINE_vertical_start

;
; 横線を描く
;
LINE_horizontal:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_horizontal_start
  CALL SWAP_X1Y1_X2Y2
LINE_horizontal_start:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(X1_POS)
  LD   HL,(X2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (X1_POS),DE
  JR   LINE_horizontal_start

;
; x軸を基準に描く
;
LINE_x_base:
  LD   HL,0
  LD   (line_drawn),HL
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_start
  CALL SWAP_X1Y1_X2Y2
LINE_x_base_start:
  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_down
LINE_x_base_up:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(X1_POS)
  LD   HL,(X2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (X1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dy)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dx)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_up
  LD   (line_drawn),HL
  LD   HL,(Y1_POS)
  DEC  HL
  LD   (Y1_POS),HL
  JR   LINE_x_base_up

LINE_x_base_down:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(X1_POS)
  LD   HL,(X2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (X1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dy)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dx)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_down
  LD   (line_drawn),HL
  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  JR   LINE_x_base_down



LINE_y_base:
  LD   HL,0
  LD   (line_drawn),HL
  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_start
  CALL SWAP_X1Y1_X2Y2
LINE_y_base_start:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_right
LINE_y_base_left:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(Y1_POS)
  LD   HL,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (Y1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dx)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dy)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_left
  LD   (line_drawn),HL
  LD   HL,(X1_POS)
  DEC  HL
  LD   (X1_POS),HL
  JR   LINE_y_base_left

LINE_y_base_right:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(Y1_POS)
  LD   HL,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (Y1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dx)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dy)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_right
  LD   (line_drawn),HL
  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL
  JR   LINE_y_base_right

line_drawn: DS 2
dx: DS 2
dy: DS 2
center_x: DS 2
center_y: DS 2
cx: DS 2
cy: DS 2
M_d: DS 2

PRESET_FLAG: DS 1
X1_POS:
X_POS: DS 2
Y1_POS:
Y_POS: DS 2

Radius:
X2_POS: DS 2
Y2_POS: DS 2

X_ORG:  DS 2

CH_NO: DS 1
NUM_BUF: DS 1
BUF_PTR: DS 2
PCG_CH_TOP: DS 2    ; PCGの１キャラクタのバッファトップ


BUFFER: DS 4*BUF_MAX
VRAM_ADR: DS 2
;PCG_RAM_ADDR: DS 2

CHAR_USED: DS 256
NUM_UNUSED: DS 1
PCG_RAM DS 128*8

  END
