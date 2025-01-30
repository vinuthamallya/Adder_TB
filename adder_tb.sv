// 1. Always add constructor for transaction inside the custom constructor of mailbox 
// 2. Always send deep copy of the transaction between driver and generator 

class transaction;
 randc bit [3:0] a ,b ;
  bit clk;
  bit [4:0] sum; 
  
  function void display();
    $display( " a = %0d \t , b %0d \t , sum = %0d " , a,b,sum);
  endfunction
  
virtual function transaction copy(); // this is to have an independent 
  copy = new();                   // obj when we send data through mbx
    copy.a = this.a;
    copy.b = this.b;
  endfunction
  
endclass

class error extends transaction;
  //constraint c { a == 0; b ==0; }
endclass

class generator ;
  mailbox #(transaction) mbx ;
  transaction t_h ;
  event done;
  
  function new (mailbox #(transaction) mbx);
    this.mbx = mbx ;
    t_h = new(); // have a single object with history across entire    
  endfunction    //randomization
  
  task run();
    for( int i=0; i<10; i++) begin
      assert(t_h.randomize());
    $display("[GEN] : Data sent to driver ");
    t_h.display();
      mbx.put(t_h.copy());
      #20;
    end
    -> done;
  endtask
    
endclass


interface add_if;
  logic [3:0] a , b;
  logic [4:0 ] sum ;
  logic clk ;

  modport DRV(output a,b, input sum,clk);
  modport MON(input sum , a , b , clk);
endinterface


class driver ;
  
transaction data;
virtual add_if.DRV vif;
mailbox #(transaction) mbx;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
    
 
  task run();
    forever begin
      mbx.get(data);
      repeat(2) @(posedge vif.clk)
      vif.a <= data.a;
      vif.b <= data.b;
      $display("[DRV]: Interface triggered");
      data.display();    
    end
  endtask
  
endclass

class monitor;
  virtual add_if.MON vif;
  mailbox #(transaction) mbx;
  transaction data;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    data = new();
  endfunction 
  
  task run();
    forever begin
      repeat(2) @(posedge vif.clk)
      data.a = vif.a ;
      data.b = vif.b ;
      data.sum = vif.sum;
      mbx.put(data);
      $display("[MON] - Monitor sent data to SB");
      data.display();
    end
  endtask
endclass

class scoreboard;
  
  mailbox #(transaction) mbx;
  transaction data;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task compare(input transaction data);
    if(data.sum == (data.a + data.b))
      $display("[SB] - SUM is MATCHED");
    else
      $error("[SB] - SUM MISMATCHED");
  endtask
     
  task run;
    forever begin
      mbx.get(data);
      $display("[SB] - RECIEVED data from monitor");
      data.display();
      compare(data);
      #40;
    end
  endtask
 
endclass

module tb;
  event done;
  add_if aif();
  generator gen_h;
  monitor mon_h;
  scoreboard sb_h;
  mailbox #(transaction) mbx1,mbx2;
  
  adder dut (.a(aif.a) ,  .b(aif.b) , .sum(aif.sum) , .clk(aif.clk));
                                                      
  initial begin 
    aif.clk <= 0;
  end
    
  always #10 aif.clk <= ~ aif.clk ;
   
  driver dv_h ;
    initial begin
      mbx1 = new();
      mbx2 = new();
      //err = new();
      gen_h = new(mbx1);
      dv_h = new(mbx1);
      mon_h = new(mbx2);
      sb_h = new(mbx2);
      dv_h.vif = aif ;
      mon_h.vif = aif;
      //done = gen_h.done;
      
    end
     
  initial begin
    fork
    gen_h.run();
    dv_h.run();
    mon_h.run();
    sb_h.run();
    join_none
    //wait(done.triggered)
    #200;
    $finish;
  end
                                                      
endmodule
