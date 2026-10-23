// Handwritten parser fixture; contains no original-game script.
anim { "synthetic.anm"; }
ecli { "synthetic-library.ecl"; }
void Synthetic()
{
    /* 100 (+ 10) */ ins_40(20);
start:
    ins_42([0]);
    ins_44([16.0f]);
+7: //7
!E
    ins_13(end, 11);
!LO
    ins_11("synthetic,(quoted)\"name", _Sf [16.0f], _fS (2));
!*
+4: //11
end:
    ins_12(start, 0);
    ins_1();
}
