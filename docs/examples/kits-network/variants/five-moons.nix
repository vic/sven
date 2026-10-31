# zerotier allows four moons: five machines make five
{ yen, ... }:
{
  yen.machine = {
    m1.addr = "10.0.2.1";
    m2.addr = "10.0.2.2";
    m3.addr = "10.0.2.3";
    m4.addr = "10.0.2.4";
    m5.addr = "10.0.2.5";
  };
  yen.assembly.crowd = {
    kit = yen.kit.zerotier;
    roles = {
      controller.at = yen.machine.lb;
      moon.at = yen.kinds.machine;
    };
  };
}
