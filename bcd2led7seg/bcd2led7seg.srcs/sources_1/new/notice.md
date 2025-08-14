1. reset => khi bấm rst thì chỉ led đầu và 3 led cuối sáng 
    => 3 led cuối đã tắt hẳn trong thiết kế
    => bấm rst chỉ led đầu sáng vì không quét được các led tiếp theo do các flip flop của counter bị rst liên tục
2. các 5 led sáng không đồng đều
    => do bị chuyển giá trị đột ngột ở cụm led 7 thanh thứ 2
    ? sau khi fix bằng cách tắt 3 led cuối thì cũng đã hết
3. khi thay đổi sw, thì 3 7seg cuối ko sử dụng lại xuất hiện giá trị lạ   
