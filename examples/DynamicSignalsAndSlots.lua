d = qt.dynamic()

function d.slot_in_qt()
  print("Slot in qt")
end

function d.slot_in_qt2()
  print("Slot in qt2")
end


qt.connect (d, "some_signal()", d, "slot_in_qt()")
qt.connect (d, "some_signal()", d, "slot_in_qt2()")

d:some_signal()
