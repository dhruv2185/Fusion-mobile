import 'package:flutter/material.dart';
import 'package:fusion/Components/appBar2.dart';
import 'package:fusion/Components/side_drawer2.dart';
import 'package:fusion/Components/bottom_navigation_bar.dart';
import 'package:fusion/screens/HR/HRHomePage.dart';
import 'package:fusion/services/service_locator.dart';
import 'package:fusion/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:fusion/screens/HR/RequestsOfAUserList.dart';
import 'package:fusion/models/profile.dart';
import 'package:fusion/services/profile_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:fusion/api.dart';

class ForwardLTC extends StatefulWidget {
  const ForwardLTC({required this.formdata, required this.isArchived});
  final Map<String, dynamic> formdata;
  final isArchived;
  @override
  State<ForwardLTC> createState() => _ForwardLTCState();
}

class _ForwardLTCState extends State<ForwardLTC> {
  TextEditingController _remarksController = TextEditingController();
  TextEditingController _receiverNameController = TextEditingController();
  TextEditingController _receiverDesignationController =
      TextEditingController();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // Prefilled data for the fields
  late Map<String, dynamic> _formdata = {"notFetched": true};
  late Map<String, dynamic> _trackingdata = {"notFetched": true};
  bool _loading1 = true;
  bool isCreator = false;
  bool isOwner = false;
  late List<dynamic> designationsOfReceiver = [];
  bool fetchedDesignationsOfReceiver = false;
  late StreamController _profileController;
  late ProfileService profileService;
  late ProfileData datap;
  
  var service = locator<StorageService>();
  late var token = service.userInDB!.token;
  late String curr_desig = service.getFromDisk("Current_designation");
  @override
  void initState() {
    // TODO: implement initState
    _profileController = StreamController();
    profileService = ProfileService();
    try {
      print("hello");
      datap = service.profileData;
      _loading1 = false;
    } catch (e) {
      getData();
    }
    fetchForm();
    trackStatus();
    super.initState();
  }

  getDesignations() async {
    final String host = kserverLink;
    final String path = "/hr2/api/getDesignations/";
    final queryParameters = {
      'username': _receiverNameController.text,
    };
    Uri uri = (Uri.http(host, path, queryParameters));
    var response = await http.get(uri,headers: {"Authorization": "Token ${token}"});
    if (response.statusCode == 200) {
      final d = await jsonDecode(response.body);
      setState(() {
        fetchedDesignationsOfReceiver = true;
        designationsOfReceiver = d;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please check the entered username.")));
    }
  }

  getData() async {
    try {
      var response = await profileService.getProfile();
      setState(() {
        datap = ProfileData.fromJson(jsonDecode(response.body));
        _loading1 = false;
      });
    } catch (e) {
      print(e);
    }
  }

  void trackStatus() async {
    final String host = kserverLink;
    final String path = "/hr2/api/tracking/";
    final queryParameters = {
      'id': widget.formdata['id'],
    };
    Uri uri = (Uri.http(host, path, queryParameters));
    print(uri);
    var response = await http.get(uri,headers: {"Authorization": "Token ${token}"});
    print(response.statusCode);
    if (response.statusCode == 200) {
      // ignore: avoid_print
      print("setting state");
      setState(() {
        _trackingdata = jsonDecode(response.body);
      });
    } else {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to Fetch Tracking Data")));
    }
    print(_trackingdata);
  }

  void archiveForm() async {
    final String host = kserverLink;
    final String path = "/hr2/api/ltc/";
    final queryParameters = {'id': widget.formdata['id']};
    Uri uri = (Uri.http(host, path, queryParameters));
    var response = await http.delete(
      uri,
      headers: {"Content-type": "application/json; charset=UTF-8","Authorization": "Token ${token}"},
      encoding: Encoding.getByName("utf-8"),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application successfully archived!")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to archive application.")));
    }
  }

  void fetchForm() async {
    final String host = kserverLink;
    final String path = "/hr2/api/formFetch/";
    // print(widget.formdata);
    final queryParameters = {
      'file_id': widget.formdata['id'],
      'id': widget.formdata['src_object_id'],
      'type': widget.formdata['file_extra_JSON']
          .substring(7, widget.formdata['file_extra_JSON'].length - 1)
    };

    Uri uri = (Uri.http(host, path, queryParameters));
    // print(queryParameters);
    Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',"Authorization": "Token ${token}"
    };

    var client = http.Client();
    var response = await client.get(uri, headers: headers);
    // print(response.body);

    if (response.statusCode == 200) {
      // ignore: avoid_print
      setState(() {
        _formdata = jsonDecode(response.body);
        isOwner = _formdata['current_owner'] == datap.user!["username"];
        isOwner = _formdata['form']['approved'] == null ? isOwner : true;
        isCreator = _formdata['creator'] == datap.user!['username'];
        isCreator = widget.isArchived ? false : isCreator;
        _loading1 = false;
      });
    } else {
      // ignore: avoid_print
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to Fetch Application")));
      setState(() {
        _loading1 = false;
      });
    }
  }

  void forwardForm() async {
    // Respond to button press
    final String host = kserverLink;
    final String path = "/hr2/api/ltc/";
    final queryParameters = {
      'id': widget.formdata['src_object_id'],
    };

    Uri uri = (Uri.http(host, path, queryParameters));
    final data = [
      {
        "file_id": widget.formdata['id'],
        "receiver": _receiverNameController.text,
        "receiver_designation": _receiverDesignationController.text,
        "remarks": _remarksController.text,
        "file_extra_JSON": {
          "type": widget.formdata['file_extra_JSON']
              .substring(7, widget.formdata['file_extra_JSON'].length - 1)
        }
      },
      _formdata["form"]
    ];
    print(data);
    var response = await http.put(
      uri,
      body: jsonEncode(data),
      headers: {"Content-type": "application/json; charset=UTF-8","Authorization": "Token ${token}"},
      encoding: Encoding.getByName("utf-8"),
    );
    if (response.statusCode == 200) {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application Forwarded Successfully")));
      Navigator.pop(context);
    } else {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application Failed to Forward")));
    }
  }

  void approveForm() async {
    final String host = kserverLink;
    final String path = "/hr2/api/ltc/";
    final queryParameters = {
      'id': widget.formdata['src_object_id'],
    };
    Uri uri = (Uri.http(host, path, queryParameters));
    final data = [
      {
        "file_id": widget.formdata['id'],
        "receiver": _formdata['creator'],
        "remarks": _remarksController.text,
        "receiver_designation": _receiverDesignationController.text,
        "file_extra_JSON": {
          "type": widget.formdata['file_extra_JSON']
              .substring(7, widget.formdata['file_extra_JSON'].length - 1)
        }
      },
      _formdata["form"]
    ];
    _formdata['form']['approved'] = true;
    _formdata['form']['approved_by'] = datap.user!["id"];
    print(data);
    var response = await http.put(
      uri,
      body: jsonEncode(data),
      headers: {"Content-type": "application/json; charset=UTF-8","Authorization": "Token ${token}"},
      encoding: Encoding.getByName("utf-8"),
    );
    if (response.statusCode == 200) {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application Approved Successfully")));
      Navigator.pop(context);
    } else {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application Failed to Approve")));
    }
  }

  void declineForm() async {
    final String host = kserverLink;
    final String path = "/hr2/api/ltc/";
    final queryParameters = {
      'id': widget.formdata['src_object_id'],
    };
    _formdata['form']['approved'] = false;
    Uri uri = (Uri.http(host, path, queryParameters));
    final data = [
      {
        "file_id": widget.formdata['id'],
        "receiver": _formdata['creator'],
        "receiver_designation": _receiverDesignationController.text,
        "remarks": _remarksController.text,
        "file_extra_JSON": {
          "type": widget.formdata['file_extra_JSON']
              .substring(7, widget.formdata['file_extra_JSON'].length - 1)
        }
      },
      _formdata["form"]
    ];
    print(data);
    var response = await http.put(
      uri,
      body: jsonEncode(data),
      headers: {"Content-type": "application/json; charset=UTF-8","Authorization": "Token ${token}"},
      encoding: Encoding.getByName("utf-8"),
    );
    if (response.statusCode == 200) {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application Declined Successfully")));
      Navigator.pop(context);
    } else {
      // ignore: avoid_print
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Application Failed to Decline")));
    }
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionTitle("Tracking Details"),
      _trackingdata['notFetched'] != null
          ? Text("Failed to Fetch Tracking History")
          : _trackingdata['status'].isEmpty
              ? Text("No Tracking History")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _trackingdata['status'].length,
                  itemBuilder: (context, index) {
                    if (_trackingdata['status'].isEmpty) {
                      return Text("No Tracking History");
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${index + 1}. Forwarded By: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(_trackingdata['status'][index]['current_id']),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "Forwarded on : ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(_trackingdata['status'][index]['forward_date']
                                .substring(0, 10)),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "Remarks : ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Flexible(
                              child: Text(_trackingdata['status'][index]
                                          ['remarks'] ==
                                      ''
                                  ? 'No Remarks'
                                  : _trackingdata['status'][index]['remarks']),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                      ],
                    );
                  }),
      SizedBox(height: 10),
      _buildSectionTitle('Personal Information'),
      Text(
        'Name: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['name']),
      SizedBox(height: 10),
      Text(
        'Designation: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['designation']),
      SizedBox(height: 10),
      Text(
        'Department: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['departmentInfo']),
      SizedBox(height: 10),
      Text(
        'Basic Pay Salary: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['basicPaySalary'].toString()),
      SizedBox(height: 10),
      Text(
        'Block Year: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['blockYear']),
      SizedBox(height: 10),
      Text(
        'PF No: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['pfNo'].toString()),
      SizedBox(height: 10),
      Text(
        'Leave Required: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['leaveRequired'].toString()),
      SizedBox(height: 10),
      Text(
        'Leave Start Date: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['leaveStartDate']),
      SizedBox(height: 10),
      Text(
        'Leave End Date: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['leaveEndDate']),
      SizedBox(height: 10),
      Text(
        'Date of Departure for Family: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['dateOfDepartureForFamily']),
      SizedBox(height: 10),
      Text(
        'Nature of Leave: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['natureOfLeave']),
      SizedBox(height: 10),
      Text(
        'Purpose of Leave: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['purposeOfLeave']),
      SizedBox(height: 10),
      Text(
        'Hometown or Not: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['hometownOrNot'].toString()),
      SizedBox(height: 10),
      Text(
        'Place of Visit: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['placeOfVisit']),
      SizedBox(height: 10),
      Text(
        'Address During Leave: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['addressDuringLeave']),
      SizedBox(height: 10),
      Text(
        'Mode of Travel: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['modeofTravel']),
      SizedBox(height: 10),
      Text(
        'Details of Family Members Already Done: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 5),
      _formdata['form']['detailsOfFamilyMembersAlreadyDone'].isEmpty
          ? Text("No Family Members")
          : ListView.builder(
              shrinkWrap: true,
              itemCount:
                  _formdata['form']['detailsOfFamilyMembersAlreadyDone'].length,
              itemBuilder: (context, index) {
                if (_formdata['form']['detailsOfFamilyMembersAlreadyDone']
                    .isEmpty) {
                  return Text("No Family Members");
                }
                print("aaaaaa");
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "${index + 1}. Name: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']
                                ['detailsOfFamilyMembersAlreadyDone'][index]
                            ['name']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Relation : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']
                                ['detailsOfFamilyMembersAlreadyDone'][index]
                            ['relation']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Age : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']
                                ['detailsOfFamilyMembersAlreadyDone'][index]
                            ['age']),
                      ],
                    ),
                  ],
                );
              }),
      SizedBox(height: 10),
      Text(
        'Details of Family Members About to Avail: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 5),
      _formdata['form']['detailsOfFamilyMembersAboutToAvail'].isEmpty
          ? Text("No Family Members")
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _formdata['form']['detailsOfFamilyMembersAboutToAvail']
                  .length,
              itemBuilder: (context, index) {
                if (_formdata['form']['detailsOfFamilyMembersAboutToAvail']
                    .isEmpty) {
                  return Text("No Family Members");
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "${index + 1}. Name: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']
                                ['detailsOfFamilyMembersAboutToAvail'][index]
                            ['name']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Relation : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']
                                ['detailsOfFamilyMembersAboutToAvail'][index]
                            ['relation']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Age : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']
                                ['detailsOfFamilyMembersAboutToAvail'][index]
                            ['age']),
                      ],
                    ),
                  ],
                );
              }),
      SizedBox(height: 10),
      Text(
        'Details of Dependents: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 5),
      _formdata['form']['detailsOfDependents'].isEmpty
          ? Text("No Dependents")
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _formdata['form']['detailsOfDependents'].length,
              itemBuilder: (context, index) {
                if (_formdata['form']['detailsOfDependents'].isEmpty) {
                  return Text("No Dependents");
                }
                print("nanana");
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("${index + 1}. Name : ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_formdata['form']['detailsOfDependents'][index]
                            ['name']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Relation : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']['detailsOfDependents'][index]
                            ['relation']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Age : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']['detailsOfDependents'][index]
                            ['age']),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Why Fully Dependent? : ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_formdata['form']['detailsOfDependents'][index]
                            ['whyFullyDependent']),
                      ],
                    ),
                  ],
                );
              }),
      SizedBox(height: 10),
      Text(
        'Amount of Advance Required: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['amountOfAdvanceRequired'].toString()),
      SizedBox(height: 10),
      Text(
        'Certified that Family Dependents: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['certifiedThatFamilyDependents'].toString()),
      SizedBox(height: 10),
      Text(
        'Certified that Advance Taken On: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['certifiedThatAdvanceTakenOn']),
      SizedBox(height: 10),
      Text(
        'Adjusted Month: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['adjustedMonth']),
      SizedBox(height: 10),
      Text(
        'Submission Date: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['submissionDate']),
      SizedBox(height: 10),
      Text(
        'Phone Number for Contact: ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(_formdata['form']['phoneNumberForContact'].toString()),
      SizedBox(height: 10),
      Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _remarksController,
              maxLength: 50,
              enabled: _formdata["form"]["approved"] == null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                label: Text('Remarks '),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some remark or NA if not applicable.';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _receiverNameController,
              maxLength: 50,
              enabled: _formdata["form"]["approved"] == null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                label: Text('Receiver\'s Name '),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter receiver name correctly or NA if not applicable.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      ElevatedButton(
          onPressed: () {
            getDesignations();
          },
          child: Text("Show Designations of user")),
      SizedBox(height: 20),
      fetchedDesignationsOfReceiver
          ? DropdownButtonFormField(
              items: designationsOfReceiver
                  .map((e) => DropdownMenuItem(
                        child: Text(e),
                        value: e,
                      ))
                  .toList(),
              onChanged: (value) {
                _receiverDesignationController.text = value.toString();
              })
          : Container(),
      SizedBox(height: 20),
      isOwner
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _formdata["form"]["approved"] == null
                    ? ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            //   // If the form is valid, display a snackbar. In the real world,
                            //   // you'd often call a server or save the information in a database.

                            forwardForm();
                          }
                          // Respond to button press
                          else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please fill all the fields correctly')),
                            );
                          }
                          // Respond to approve button press
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 202, 122, 69),
                        ),
                        child: Text(
                          'Forward',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Container(),
                _formdata["form"]["approved"] == null
                    ? ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            //   // If the form is valid, display a snackbar. In the real world,
                            //   // you'd often call a server or save the information in a database.
                            print("pohoch");
                            declineForm();
                          }
                          // Respond to button press
                          else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please fill all the fields correctly')),
                            );
                          }
                          // Respond to decline button press
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 64, 162, 201),
                        ),
                        child: Text(
                          'Decline',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Container(),
                _formdata["form"]["approved"] == null
                    ? ElevatedButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("Approve Application"),
                                  content: Text(
                                      "Are you sure you want to approve this application?"),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text("Cancel")),
                                    TextButton(
                                        onPressed: () {
                                          approveForm();
                                          Navigator.of(context).pop();
                                        },
                                        child: Text("Approve"))
                                  ],
                                );
                              });
                          // Respond to decline button press
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 64, 162, 201),
                        ),
                        child: Text(
                          'Approve',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Container(),
                _formdata["form"]["approved"] == true
                    ? Text(
                        "Application Approved by ${_formdata['form']['approved_by']}",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold))
                    : Container(),
                _formdata["form"]["approved"] == false
                    ? Text("Application Declined",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold))
                    : Container(),
              ],
            )
          : Container(
              child: Text(
                  "You are not the owner of this form. You have already forwarded this form."),
            ),
      SizedBox(height: 20),
      isCreator
          ? ElevatedButton(
              onPressed: () {
                //  show alert dialog box
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Archive Application"),
                        content: Text(
                            "Are you sure you want to archive this application? This action cannot be undone!"),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("Cancel")),
                          TextButton(
                              onPressed: () {
                                archiveForm();
                                Navigator.of(context).pop();
                              },
                              child: Text("Archive this form"))
                        ],
                      );
                    });
                // approveForm();
                // Respond to decline button press
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 64, 162, 201),
              ),
              child: Text(
                'Archive this form.',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            )
          : Container(),
      SizedBox(
        height: 10,
      ),
      widget.isArchived
          ? Text("This form has been archived.",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20))
          : Container(),
      SizedBox(
        height: 10,
      )
    ]);
  }

  Widget _buildListTile(
      BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: Icon(
        icon,
        size: 48.0, // Adjust the size of the icon as needed
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18.0, // Adjust the size of the title as needed
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        curr_desig: curr_desig,
        headerTitle: "View LTC Form",
        onDesignationChanged: (newValue) {
          setState(() {
            curr_desig = newValue;
          });
        },
      ), // This is default app bar used in all modules
      drawer: SideDrawer(curr_desig: curr_desig),
      bottomNavigationBar: MyBottomNavigationBar(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _formdata["notFetched"] == true
                    ? _loading1
                        ? CircularProgressIndicator()
                        : Center(child: Text("Failed to Fetch Application"))
                    : Column(
                        children: [
                          _buildListTile(
                            context,
                            Icons.assignment,
                            'View Previous ${widget.formdata['file_extra_JSON'].substring(7, widget.formdata['file_extra_JSON'].length - 1)} Requests by ${_formdata['form']['name']}',
                            RequestsOfAUserListPage({
                              // id of the creator of this file,
                              'id': _formdata['creator'],
                              'type': widget.formdata['file_extra_JSON']
                                  .substring(
                                      7,
                                      widget.formdata['file_extra_JSON']
                                              .length -
                                          1)
                            }),
                          ),
                          SizedBox(height: 20),
                          _buildForm(),
                        ],
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
