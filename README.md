# PCG8100用グラフィックルーチン群とデモプログラム
ちくらっぺさん([@chiplappe](https://twitter.com/chiqlappe))の[新PCG](https://github.com/chiqlappe/new_pcg)のデモ用の
[ライブラリ](https://github.com/kazenif/new_pcg)を
ベースに、PCG8100向けに移植したバージョンです。

40桁×25行モードで実行するので、320×200ドットのグラフィックが扱えます。

機能としては、

- 点を打つ
- ラインを引く
- 円を描く
- BOXを描く

が行えます。

- 描画実行時に、引数を追加 0:PSET(描画), 1:PRESET(消去), 2:XOR(XOR)の３つのモードを実現
- CIRCLEで同じ場所に２回プロットしないように、処理を追加
- 
ソースをいじれば、80桁×40行でも実行可能ですが、すぐに文字が足りなくなりそうなので、
ドットが正方形になることも含めて、40桁モードを利用してます。

# 動作原理
最初にPCGのパタンを0で全クリア。画面を文字コード0で埋めておく。<br>
ドットをプロットする際は、次の手順で実行。

1. 当該位置に文字コード&H80 以上の文字が存在すれば、その文字に対して、ドットを追加
2. 文字が存在しない場合は、PCGの未使用文字を検索し、当該位置に文字を置き、ドットを追加。未使用文字を使用中と記録。
3. 未使用文字がない場合は、これ以上プロットできないものとして、プロットリクエストを無視。

# 利用時の準備
D000Hよりマシン語で書かれているので、BASICプログラムでは
```
CLEAR 300, &HCFFF
```
を記述してください。詳細な記述方法は、[デモプログラム](#デモプログラム)を参照ください。

新PCGをグラフィック画面的に使用するサブルーチン群は、```old_pcg_01.cmt```にマシン語ファイルとして格納されています。
プログラムは、ほぼ　[新PCG向けグラフィックライブラリ](https://github.com/kazenif/new_pcg)のプログラムがそのまま
使用できますが、ライブラリのエントリポイントが &HD000 から始まっているので、その点だけは修正してください。

ライブラリを&HC000 スタートにアセンブルしなおすことで、デモプログラムをそのまま使用することもできます。

# メモリマップ
メモリマップは以下の通り。PCG内の登録パタンを本体メモリ側に格納する必要があるため、それだけで1kByteのメモリが必要に
なります。PCG登録パタンの容量が少なくなったことから、ライブラリルーチンの開始アドレスを &HD000 からにしています。

![メモリマップ](./memry_map_old_pcg.png)

# 基本的な使い方
DEF USR を使って、ユーザ関数として呼び出します。引数は、整数型です。

```
DEF USR1=&hD000 : A%=USR1(0)     : 'PCGの初期化
DEF USR2=&hD003 : A%=USR2(X1%)   : 'X1座標のセット
DEF USR3=&hD006 : A%=USR3(Y1%)   : 'Y1座標のセット
DEF USR4=&hD009 : A%=USR4(X2%)   : 'X2座標のセット
DEF USR5=&hD00C : A%=USR5(Y2%)   : 'Y2座標のセット
DEF USR6=&HD00F : A%=USR6(0|1|2) : 'PSET/PRESET/PXOR(X1, Y1) 実施。 引数0:PSET,1:PRESET,2:XOR
DEF USR7=&HD012 : A%=USR7(0|1|2|4|5|6|8|9|12) : '(X1,Y1)-(X2,Y2)にラインを描画。引数で，0:line, 1:line preset, 2:line xor, 4:box, 5:box preset, 6:box xor, 8:boxfill, 9:boxfill preset, 12:boxfill xor 実行
DEF USR8=&HD015 : A%=USR8(0|1|2) : '(X1,Y1)を中心に半径X2 の円を描く。引数0:PSET,1:PRESET,2:XOR
DEF USR9=&HD018 : A%=USR9(0)     : 'バッファフラッシュ
```

## 初期化(画面クリア)
PCGや画面の初期化は、&HD000 のルーチンで行います。
```
DEF USR1=&hD000 : A%=USR1(0): 'PCGの初期化
LOCATE 0,0,0                : 'カーソル非表示
```
40桁×25行、白黒モードで初期化されます。
また、カーソルは ```locate 0,0,0``` で非表示にしておくとよいです。

### pset
グラフィックで(X%, Y%)座標に１点プロットを打つ手順は以下の通り

1. ```DEF USR2=&HD003``` の ```A%=USR2(X%)``` でX座標を指定、
2. ```DEF USR3=&HD006``` の ```A%=USR3(Y%)``` でY座標を指定
3. ```DEF USR6=&HD00F``` の ```A%=USR6(0|1|2)```でPSET実行.引数0:PSET,1:PRESET,2:XOR
4. 1～3を必要なだけ繰り返す
5. ```DEF USR9=&HD018``` の ```A%=USR9(0)```でバッファ上のPCGの設定を反映させる

プロットは、16点プロットされるごとに、PCGに対してVSYNC待ちを行い、反映されます。
毎回PCGに対して反映させたい場合は、明示的に```A%=USR9(0)```を実行してください。

### line, box, boxfill
グラフィックで(X1%, Y1%)-(X2%,Y2%)に直線を描画する

1. ```DEF USR2=&HD003``` の ```A%=USR2(X1%)``` でX1座標を指定、
2. ```DEF USR3=&HD006``` の ```A%=USR3(Y1%)``` でY1座標を指定
3. ```DEF USR4=&HD009``` の ```A%=USR4(X2%)``` でX2座標を指定、
4. ```DEF USR5=&HD00C``` の ```A%=USR5(Y2%)``` でY2座標を指定
5. ```DEF USR7=&HD012``` の ```A%=USR7(0|1|2|4|5|6|8|9|12)``` 引数により　0:line, 1:line preset, 2:line xor, 4:box, 5:box preset, 6:box xor, 8:boxfill, 9:boxfill preset, 12:boxfill xor 実行
6. 1～5を必要なだけ繰り返す
7. ```DEF USR9=&HD018``` の ```A%=USR9(0)```でバッファ上のPCGの設定を反映させる

line では、内部的に pset 機能が呼び出され、16点プロットされるごとに、
PCGに対してVSYNC待ちを行い、反映されます。毎回PCGに対して反映させたい場合は、
明示的に```A%=USR9(0)```を実行してください。

### circle
グラフィックで、(X%, Y%)座標を中心、半径R%の円を描く

1. ```DEF USR2=&HD003``` の ```A%=USR2(X%)``` でX座標を指定、
2. ```DEF USR3=&HD006``` の ```A%=USR3(Y%)``` でY座標を指定
3. ```DEF USR4=&HD009``` の ```A%=USR4(R%)``` で半径を指定、
4. ```DEF USR8=&HD015``` の ```A%=USR8(0|1|2)``` でcircle実行.引数0:PSET,1:PRESET,2:XOR
5. 1～4を必要なだけ繰り返す
6. ```DEF USR9=&HD018``` の ```A%=USR9(0)```でバッファ上のPCGの設定を反映させる

circle では、内部的に pset 機能が呼び出され、16点プロットされるごとに、
PCGに対してVSYNC待ちを行い、反映されます。基本的に、circleでは円を８分割して描画して
いるので、毎回バッファのフラッシュを行う必要はなく、
最後に```A%=USR9(0)```を実行するだけで十分だと考えられます。


#### 円描画アルゴリズム
円描画アルゴリズムは、[伝説のお茶の間](https://dencha.ojaru.jp/index.html)で解説されている、
[ミッチェナー(Miechener) の円描画](https://dencha.ojaru.jp/programs_07/pg_graphic_09a1.html)の
コードをベースに、同じ点を２度プロットしないような条件を加えたコードになっています。

コード修正の目的は、XOR 描画モードで描画しても、途中で途切れることや、２回 XOR 描画モードで描画した際の消し忘れ
が起きないようにするためのものです。

```
void MiechenerCircle (HDC hdc, LONG radius, POINT center, COLORREF col){
    LONG cx, cy, d;

    d = 3 - 2 * radius;
    cy = radius;

    // 開始点の描画
    SetPixel (hdc, center.x, radius + center.y, col);   // point (0, R);
    SetPixel (hdc, center.x, -radius + center.y, col);  // point (0, -R);
    SetPixel (hdc, radius + center.x, center.y, col);   // point (R, 0);
    SetPixel (hdc, -radius + center.x, center.y, col);  // point (-R, 0);

    for (cx = 0; cx <= cy; cx++) {
        if (d < 0)  d += 6  + 4 * cx;
        else        d += 10 + 4 * cx - 4 * cy--;

        // 描画 ※ブロック内の２つのif文は、２度同じ場所にプロットしない為のコード
        if (cx <= cy) {
            SetPixel (hdc,  cy + center.x,  cx + center.y, col);        // 0-45     度の間
            SetPixel (hdc, -cx + center.x,  cy + center.y, col);        // 90-135   度の間
            SetPixel (hdc, -cy + center.x, -cx + center.y, col);        // 180-225  度の間
            SetPixel (hdc,  cx + center.x, -cy + center.y, col);        // 270-315  度の間
        
            if (cx != cy) {
                SetPixel (hdc,  cx + center.x,  cy + center.y, col);    // 45-90    度の間
                SetPixel (hdc, -cy + center.x,  cx + center.y, col);    // 135-180  度の間
                SetPixel (hdc, -cx + center.x, -cy + center.y, col);    // 225-270  度の間
                SetPixel (hdc,  cy + center.x, -cx + center.y, col);    // 315-360  度の間
            }
        }
    }
}
```
