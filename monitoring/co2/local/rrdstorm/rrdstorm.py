import argparse
import logging
import os
import subprocess
from datetime import datetime, timedelta

class RRDStorm:
    def __init__(self, args):
        self.args = args
        self.rrdtool = args.rrdtool
        self.rrddata = args.rrddata
        self.rrdoutput = args.rrdoutput
        self.forcegraph = args.forcegraph

        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    def create_rrd(self, rrdfile, step, definition):
        logging.info(f"Creating RRD file: {rrdfile}")
        subprocess.run([self.rrdtool, "create", rrdfile, "--step", str(step), *definition.split()], check=True)

    def update_rrd(self, rrdfile, data_sources, values):
        t = int(datetime.now().timestamp()) // 60 * 60
        logging.info(f"Updating RRD file: {rrdfile} with values: {values}")
        subprocess.run([self.rrdtool, "update", rrdfile, "-t", data_sources, f"{t}:{values}"], check=True)

    def create_graph(self, imgfile, secs_to_go_back, um_text, title_text, rrdfile, definition, extra_params):
        logging.info(f"Creating graph: {imgfile}")
        start_time = int((datetime.now() - timedelta(seconds=secs_to_go_back)).timestamp())
        end_time = int(datetime.now().timestamp()) - 20
        command = [
            self.rrdtool,
            "graph",
            imgfile,
            "-M",
            "-a", "SVG",
            "-s", str(start_time),
            "-e", str(end_time),
            "-w", "550",
            "-h", "240",
            "-v", um_text,
            "-t", title_text,
            *definition.split(),
            *extra_params.split()
        ]
        subprocess.run(command, check=True)

    def run(self):
        command = self.args.command
        cron_graph_time = self.args.cron_graph_time

        if command == "create":
            self.create_html_index()
            for n in self.args.numbers:
                self.handle_create(n)
        elif command == "update":
            for n in self.args.numbers:
                self.handle_update(n)
        elif command == "help":
            self.print_help()
        elif command == "graph":
            for n in self.args.numbers:
                self.handle_graph(n)
        elif command == "graph_cron":
            if cron_graph_time and len(self.args.numbers) == 1:
                self.handle_graph_cron(cron_graph_time, self.args.numbers[0])
            else:
                logging.error("Invalid usage for graph_cron")
                exit(1)
        else:
            logging.error("Unknown command")
            exit(1)

    def create_html_index(self):
        if not os.path.exists(self.rrdoutput):
            os.makedirs(self.rrdoutput)
        htmlindex = os.path.join(self.rrdoutput, "storj.html")
        if not os.path.exists(htmlindex):
            with open(htmlindex, 'w') as f:
                f.write("<head><title>RRDStorm</title>\n"
                        "<style>body{background:white;color:black}</style></head>\n"
                        "<body><h1>RRDStorm</h1><ul>")
            self.make_index = True

    def handle_create(self, n):
        if not hasattr(self, f"rrdcfile_{n}"):
            logging.warning(f"N {n} does not exist")
            return
        filebase = getattr(self, f"rrdcfile_{n}").split(':')[0]
        rrdfile = os.path.join(self.rrddata, f"{filebase}.rrd")
        htmlfile = os.path.join(self.rrdoutput, f"{filebase}.html")

        if not os.path.exists(self.rrddata):
            os.makedirs(self.rrddata)
        if not os.path.exists(rrdfile):
            self.create_rrd(rrdfile, int(getattr(self, f"rrdcfile_{n}").split(':')[1]), getattr(self, f"rrdcdef_{n}"))

        if not os.path.exists(htmlfile):
            with open(htmlfile, 'w') as f:
                f.write(f"<head><title>{getattr(self, f'rrdcfile_{n}').split(':')[2]}</title>\n"
                        "<style>body{background:white;color:black}</style></head>\n"
                        "<body style=\"background-color:black;color:lightgray\"><h1>{getattr(self, f'rrdcfile_{n}').split(':')[2]}</h1><center>")
                for p in getattr(self, f"rrdglist_{n}").split():
                    if not hasattr(self, f"rrdgraph_{p}"):
                        continue
                    imgbase = self.rrdgraph_[p].split('|')[1]
                    f.write(f"<img src=\"{imgbase}.svg\"><br>")
                f.write("</center><p>RRDStorm for {self.args.version} / {datetime.now().strftime('%x %R')}</p></body>")

            # Creating timed dash files
            for f in "4h:4 Hours dashboard:12 19 54 24 30 48 36 42" "1d:1 Day dashboard:13 20 56 26 32 50 38 44":
                timedfilename, timedfiletitle, timedfilesources = f.split(':')
                dashfile = os.path.join(self.rrdoutput, f"{timedfilename}.html")
                with open(dashfile, 'w') as f:
                    f.write(f"<head><title>{timedfiletitle}</title>\n"
                            "<style>body{background:white;color:black}</style></head>\n"
                            "<body style=\"background-color:black;color:lightgray\"><h1>{timedfiletitle}</h1><center>")
                    for p in timedfilesources.split():
                        if not hasattr(self, f"rrdgraph_{p}"):
                            continue
                        imgbase = self.rrdgraph_[p].split('|')[1]
                        htmlfilebaseindex = int(p) // 6
                        htmlfilebase = getattr(self, f"rrdcfile_{htmlfilebaseindex}").split(':')[0]
                        f.write(f"<a href=\"{htmlfilebase}.html\"><img src=\"{imgbase}.svg\"></a><br>")
                    f.write("</center><p>RRDStorm for {self.args.version} / {datetime.now().strftime('%x %R')}</p></body>")

        if self.make_index:
            with open(os.path.join(self.rrdoutput, "storj.html"), 'a') as f:
                f.write(f"<li><a href=\"{filebase}.html\">{getattr(self, f'rrdcfile_{n}').split(':')[2]}</a>")

    def handle_update(self, n):
        if not hasattr(self, f"rrducval_{n}"):
            logging.warning(f"N {n} does not exist")
            return
        val = eval(getattr(self, f"rrducval_{n}"))
        self.update_rrd(os.path.join(self.rrddata, f"{getattr(self, f'rrdcfile_{n}').split(':')[0]}.rrd"), getattr(self, f"rrduval_{n}"), val)

    def print_help(self):
        logging.info("Usage: rrdstorm {create|update|graph|graph_cron[s h d w m y]} 0 1 2 ..")
        logging.info("graph_cron is for cron to quickly update just one graph [1h=s 4h=h 24h=d 1week=w 1 month=m 1year=y]} 0 1 2 ..")

    def handle_graph(self, n):
        m = datetime.now().strftime("%M")
        h = datetime.now().strftime("%H")
        for p in getattr(self, f"rrdglist_{n}").split():
            if not hasattr(self, f"rrdgraph_{p}"):
                continue
            back, imgbase, title, cond, extra = self.rrdgraph_[p].split('|')
            ret = 1 if self.forcegraph else eval(cond) if cond else 1
            if ret == 1:
                title += f" @ \"{h}\":\"{m}\""
                self.create_graph(os.path.join(self.rrdoutput, f"{imgbase}.svg"), int(back), getattr(self, f"rrdgum_{n}"), title,
                                  os.path.join(self.rrddata, f"{getattr(self, f'rrdcfile_{n}').split(':')[0]}.rrd"),
                                  getattr(self, f"rrdgdef_{n}"), extra)

    def handle_graph_cron(self, cron_graph_time, n):
        m = datetime.now().strftime("%M")
        h = datetime.now().strftime("%H")
        if cron_graph_time == "s":
            cron_sub_graph = 0
        elif cron_graph_time == "h":
            cron_sub_graph = 1
        elif cron_graph_time == "d":
            cron_sub_graph = 2
        elif cron_graph_time == "w":
            cron_sub_graph = 3
        elif cron_graph_time == "m":
            cron_sub_graph = 4
        elif cron_graph_time == "y":
            cron_sub_graph = 5
        else:
            logging.error("Invalid cron graph time")
            exit(1)

        p = (((n + 1) * 6) - 6) + cron_sub_graph
        if not hasattr(self, f"rrdgraph_{p}"):
            logging.warning(f"P {p} does not exist")
            return

        back, imgbase, title, cond, extra = self.rrdgraph_[p].split('|')
        ret = 1 if self.forcegraph else eval(cond) if cond else 1
        if ret == 1:
            self.create_graph(os.path.join(self.rrdoutput, f"{imgbase}.svg"), int(back), getattr(self, f"rrdgum_{n}"), title,
                              os.path.join(self.rrddata, f"{getattr(self, f'rrdcfile_{n}').split(':')[0]}.rrd"),
                              getattr(self, f"rrdgdef_{n}"), extra)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RRDStorm script")
    parser.add_argument("command", choices=["create", "update", "graph", "graph_cron"])
    parser.add_argument("cron_graph_time", nargs='?', default=None, choices=["s", "h", "d", "w", "m", "y"])
    parser.add_argument("numbers", type=int, nargs='+')
    parser.add_argument("--rrdtool", default="/usr/bin/rrdtool", help="Path to rrdtool")
    parser.add_argument("--rrddata", default="/var/lib/rrd/storj", help="Directory for RRD data files")
    parser.add_argument("--rrdoutput", default="/dev/shm/rrd.img", help="Directory for output images")
    parser.add_argument("--forcegraph", action='store_true', help="Force graph creation")

    args = parser.parse_args()

    rrdstorm = RRDStorm(args)
    rrdstorm.run()
