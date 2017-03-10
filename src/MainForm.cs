using System;
using System.Data;
using System.Data.SqlClient;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

namespace AlterCollation
{
    public class MainForm : Form, IScriptExecuteCallback
    {
        private bool canceled;


        private bool collationPopulated;
        private bool executeScriptOnly;

        private ScriptStepCollection executingScript;
        private int lastReportedStep;


        private bool textLanguagePopulated;
        private ViewMode viewMode;

        private Thread workerThread;
        private WorkerThreadArguments workerThreadArguments;

        public MainForm()
        {
            InitializeComponent();
        }


        private void Script()
        {
            if (viewMode == ViewMode.Running)
            {
                MessageBox.Show("Already Running Something");
            }
            else
            {
                ViewModeSet(ViewMode.Running);
                feedbackL.Clear();

                if (workerThread != null)
                    throw new InvalidOperationException("Oops worker thread still running");

                //workerThread = new Thread(
                workerThreadArguments = new WorkerThreadArguments(true, this, serverE.Text, userIdE.Text, passwordE.Text,
                    databaseE.Text, dropAllE.Checked, collationE.Text, languageE.SelectedItem as FullTextLanguage,
                    singleUserE.Checked);
                workerThread = new Thread(ScriptThreadProc);
                workerThread.Start();
            }
        }

        private void ScriptThreadProc()
        {
            //WorkerThreadArguments arguments = (WorkerThreadArguments)threadArguments;
            var collationChanger = new CollationChanger();
            ScriptStepCollection script = null;
            SqlConnection connection = null;
            try
            {
                script = collationChanger.GenerateScript(workerThreadArguments.Callback, workerThreadArguments.Server,
                    workerThreadArguments.UserId, workerThreadArguments.Password, workerThreadArguments.Database,
                    workerThreadArguments.DropAllConstraints, workerThreadArguments.Collation,
                    workerThreadArguments.Language, workerThreadArguments.SetSingleUser);
                if (script != null)
                    if (workerThreadArguments.ScriptOnly)
                    {
                        BeginInvoke(new ScriptCompleteCallback(ScriptComplete), script);
                    }
                    else
                    {
                        connection =
                            new SqlConnection(Utils.ConnectionString(workerThreadArguments.Server,
                                workerThreadArguments.UserId, workerThreadArguments.Password));
                        connection.Open();
                        script.Execute(connection, workerThreadArguments.Callback);
                        BeginInvoke(new ExecuteCompleteCallback(ExecuteComplete));
                    }
                else
                    BeginInvoke(new ScriptCompleteCallback(ScriptComplete), new object[] {null});
            }
            catch (ThreadAbortException)
            {
                throw;
            }
            catch (Exception ex)
            {
                BeginInvoke(new ScriptCompleteErrorCallback(ScriptComplete), ex);
            }
            finally
            {
                if (connection != null)
                    connection.Dispose();
            }

            lock (this)
            {
                workerThread = null;
            }
        }

        private void ExecuteComplete()
        {
            if (!canceled)
                MessageBox.Show("Execution Complete", Text);
            progressBar.Value = progressBar.Maximum;
            ViewModeSet(ViewMode.Normal);
        }

        /// <summary>
        ///     callback from worker thread when something goes wrong
        /// </summary>
        /// <param name="ex"></param>
        private void ScriptComplete(Exception ex)
        {
            MessageBox.Show(ex.Message, Text);
            progressBar.Value = progressBar.Maximum;
            ViewModeSet(ViewMode.Normal);
        }

        /// <summary>
        ///     callback from worker thread when it went OK
        /// </summary>
        /// <param name="script"></param>
        private void ScriptComplete(ScriptStepCollection script)
        {
            if (script != null)
                WriteScriptToWindow(script);
            progressBar.Value = progressBar.Maximum;
            ViewModeSet(ViewMode.Normal);
        }


        private void WriteScriptToWindow(ScriptStepCollection script)
        {
            feedbackL.Clear();
            foreach (ScriptStep step in script)
            {
                feedbackL.AppendText(step.CommandText);
                feedbackL.AppendText("\n\nGO\n\n");
            }
        }

        private void ViewModeSet(ViewMode viewMode)
        {
            this.viewMode = viewMode;
            serverE.Enabled = viewMode == ViewMode.Normal;
            integratedE.Enabled = viewMode == ViewMode.Normal;
            userIdE.Enabled = (viewMode == ViewMode.Normal) && !integratedE.Checked;
            passwordE.Enabled = (viewMode == ViewMode.Normal) && !integratedE.Checked;
            databaseE.Enabled = viewMode == ViewMode.Normal;
            collationE.Enabled = viewMode == ViewMode.Normal;
            languageE.Enabled = viewMode == ViewMode.Normal;
            scriptB.Enabled = viewMode == ViewMode.Normal;
            executeB.Enabled = viewMode == ViewMode.Normal;
            dropAllE.Enabled = viewMode == ViewMode.Normal;
            cancelB.Enabled = viewMode == ViewMode.Running;
            singleUserE.Enabled = viewMode == ViewMode.Normal;
            cancelTimer.Enabled = viewMode == ViewMode.Aborting;

            switch (viewMode)
            {
                case ViewMode.Running:
                    canceled = false;
                    break;
                case ViewMode.Aborting:
                    canceled = true;
                    break;
                case ViewMode.Normal:
                    break;
            }
        }


        //private void ExecuteDo()
        //{
        //    canceled = false;
        //    ScriptRunner scriptRunner = new ScriptRunner();

        //    scriptRunner.Execute(serverE.Text, userIdE.Text, passwordE.Text,databaseE.Text, dropAllE.Checked, collationE.Text, (FullTextLanguage)languageE.SelectedItem);
        //    ExecuteComplete();

        //}


        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            ViewModeSet(ViewMode.Normal);
        }

        private void executeB_Click(object sender, EventArgs e)
        {
            if (viewMode == ViewMode.Running)
            {
                MessageBox.Show("Already Running Something");
            }
            else
            {
                if (
                    MessageBox.Show(
                        "This program will now execute a script to alter the collation of your database.  This may take a long time and may result in data loss.  Please ensure that all your data is backed up.\n\nExclusive database access is required to complete the process so before running use the sp_who command to verify that there are no users connected to your database.",
                        "Confirm", MessageBoxButtons.OKCancel, MessageBoxIcon.Stop, MessageBoxDefaultButton.Button2) ==
                    DialogResult.OK)
                {
                    ViewModeSet(ViewMode.Running);
                    feedbackL.Clear();

                    if (workerThread != null)
                        throw new InvalidOperationException("Oops worker thread still running");

                    workerThreadArguments = new WorkerThreadArguments(false, this, serverE.Text, userIdE.Text,
                        passwordE.Text, databaseE.Text, dropAllE.Checked, collationE.Text,
                        languageE.SelectedItem as FullTextLanguage, singleUserE.Checked);
                    workerThread = new Thread(ScriptThreadProc);
                    workerThread.Start();
                }
            }
        }

        private void integratedE_CheckedChanged(object sender, EventArgs e)
        {
            if (integratedE.Checked)
            {
                userIdE.Text = string.Empty;
                passwordE.Text = string.Empty;
            }

            userIdE.Enabled = !integratedE.Checked;
            userIdL.Enabled = !integratedE.Checked;
            passwordE.Enabled = !integratedE.Checked;
            passwordL.Enabled = !integratedE.Checked;
        }

        private void scriptB_Click(object sender, EventArgs e)
        {
            Script();
        }

        private void languageE_DropDown(object sender, EventArgs e)
        {
            if (!textLanguagePopulated)
            {
                textLanguagePopulated = true;
                var con = new SqlConnection();

                try
                {
                    SqlCommand cmd;
                    int ixName;
                    int ixLcid;
                    SqlDataReader dr;
                    Version serverVersion;
                    con.ConnectionString = Utils.ConnectionString(serverE.Text, userIdE.Text, passwordE.Text);
                    con.Open();
                    serverVersion = new Version(con.ServerVersion);

                    cmd = con.CreateCommand();


                    if (serverVersion.Major >= 9)
                    {
                        cmd.CommandType = CommandType.Text;
                        cmd.CommandText = "select * from sys.fulltext_languages";
                    }
                    else
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.CommandText = "master..xp_MSFullText";
                    }

                    dr = cmd.ExecuteReader(CommandBehavior.CloseConnection);


                    if (serverVersion.Major >= 9)
                        ixName = dr.GetOrdinal("name");
                    else
                        ixName = dr.GetOrdinal("Language");

                    ixLcid = dr.GetOrdinal("LCID");

                    languageE.Items.Clear();
                    languageE.Items.Add(new FullTextLanguage("<Unchanged>", int.MinValue));
                    while (dr.Read())
                        languageE.Items.Add(new FullTextLanguage(dr.GetString(ixName), dr.GetInt32(ixLcid)));
                }

                catch (SqlException)
                {
                    textLanguagePopulated = false;
                }
                catch (Exception)
                {
                    textLanguagePopulated = false;
                    throw;
                }
                finally
                {
                    con.Dispose();
                }
            }
        }

        private void cancelB_Click(object sender, EventArgs e)
        {
            ViewModeSet(ViewMode.Aborting);
        }

        private void serverE_TextChanged(object sender, EventArgs e)
        {
            collationPopulated = false;
            textLanguagePopulated = false;
            collationE.Items.Clear();

            languageE.Items.Clear();
            languageE.Items.Add(new FullTextLanguage("<Unchanged>", int.MinValue));
        }

        private void collationE_DropDown(object sender, EventArgs e)
        {
            //populate the list

            if (!collationPopulated)
            {
                collationPopulated = true;
                var con = new SqlConnection();

                try
                {
                    SqlCommand cmd;
                    int ixName;
                    SqlDataReader dr;

                    con.ConnectionString = Utils.ConnectionString(serverE.Text, userIdE.Text, passwordE.Text);
                    con.Open();
                    cmd = con.CreateCommand();
                    cmd.CommandType = CommandType.Text;
                    cmd.CommandText = "select name from ::fn_helpCollations()";
                    dr = cmd.ExecuteReader(CommandBehavior.CloseConnection);
                    ixName = dr.GetOrdinal("name");
                    collationE.Items.Clear();
                    while (dr.Read())
                        collationE.Items.Add(dr.GetString(ixName));
                }
                catch (SqlException)
                {
                    collationPopulated = false;
                }
                catch (Exception)
                {
                    collationPopulated = false;
                    throw;
                }
                finally
                {
                    con.Dispose();
                }
            }
        }


        private void UpdateUI(int step)
        {
            lock (this)
            {
                if (lastReportedStep == -1)
                {
                    feedbackL.Clear();
                    lastReportedStep = 0;
                }
                ScriptStep scriptItem;
                for (var index = lastReportedStep; index < step; index++)
                {
                    scriptItem = executingScript[index];
                    feedbackL.AppendText(scriptItem.CommandText);
                    feedbackL.AppendText("\n\nGO\n\n");
                }
                progressBar.Maximum = executingScript.Count;
                progressBar.Value = step;
                lastReportedStep = step;
            }
        }


        private bool ScriptError(ScriptStep step, Exception exception)
        {
            var ex = exception as SqlException;
            if (ex == null)
            {
                MessageBox.Show("Unexpeced error");
                return false;
            }

            for (var stepIndex = 0; stepIndex < executingScript.Count; stepIndex++)
                if (ReferenceEquals(executingScript[stepIndex], step))
                {
                    UpdateUI(stepIndex + 1);
                    break;
                }


            foreach (SqlError e in ex.Errors)
            {
                if (e.Class >= 11)
                    feedbackL.SelectionColor = Color.Red;
                else
                    feedbackL.SelectionColor = Color.Black;
                feedbackL.AppendText(string.Format("{0} - {1}", e.Number, e.Message));
                feedbackL.AppendText("\n");
            }

            if (ex.Class >= 11)
            {
                var commandText = step.CommandText;
                if (commandText.Length > 1000)
                    commandText = commandText.Substring(0, 1000) + "......";

                var message =
                    string.Format(
                        "An error occured while executing the SQL Statement\n\n '{0}'\n\n{1}\n\nDo you which to continue running the script anyway?",
                        commandText, ex.Message);
                if (
                    !(MessageBox.Show(this, message, "Error", MessageBoxButtons.YesNo, MessageBoxIcon.Stop) ==
                      DialogResult.Yes))
                {
                    canceled = true;
                    feedbackL.SelectionColor = Color.Red;
                    feedbackL.AppendText("Canceled");
                    feedbackL.AppendText("\n");
                }
            }


            return !canceled;
        }

        private void cancelTimer_Tick(object sender, EventArgs e)
        {
            lock (this)
            {
                if (workerThread != null)
                    workerThread.Abort();
                workerThread = null;
            }
            progressBar.Value = progressBar.Maximum;
            ViewModeSet(ViewMode.Normal);
        }

        //private delegate ScriptStepCollection GenerateScript(IScriptExecuteCallback callback, string server, string userId, string password, string database, bool dropAllConstraints, string collation, FullTextLanguage language);


        private delegate void UpdateUICallback(int step);

        private delegate bool ScriptErrorCallback(ScriptStep step, Exception ex);

        private delegate void ScriptCompleteCallback(ScriptStepCollection script);

        private delegate void ScriptCompleteErrorCallback(Exception ex);

        private delegate void ExecuteCompleteCallback();

        private class WorkerThreadArguments
        {
            public WorkerThreadArguments(bool scriptOnly, IScriptExecuteCallback callback, string server, string userId,
                string password, string database, bool dropAllConstraints, string collation, FullTextLanguage language,
                bool setSingleUser)
            {
                ScriptOnly = scriptOnly;
                Callback = callback;
                Server = server;
                UserId = userId;
                Password = password;
                Database = database;
                DropAllConstraints = dropAllConstraints;
                Collation = collation;
                Language = language;
                SetSingleUser = setSingleUser;
            }

            public bool ScriptOnly { get; }

            public IScriptExecuteCallback Callback { get; }

            public string Server { get; }

            public string UserId { get; }

            public string Password { get; }

            public string Database { get; }

            public bool DropAllConstraints { get; }

            public string Collation { get; }

            public FullTextLanguage Language { get; }

            public bool SetSingleUser { get; }
        }

        private enum ViewMode
        {
            Normal,
            Running,
            Aborting
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///     Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///     Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        private System.Windows.Forms.CheckBox dropAllE;
        private System.Windows.Forms.Button cancelB;
        private System.Windows.Forms.ComboBox languageE;
        private System.Windows.Forms.Label languageL;
        private System.Windows.Forms.Label labelNote2;
        private System.Windows.Forms.Label labelNote1;
        private System.Windows.Forms.ComboBox collationE;
        private System.Windows.Forms.ProgressBar progressBar;
        private System.Windows.Forms.Button scriptB;
        private System.Windows.Forms.RichTextBox feedbackL;
        private System.Windows.Forms.Button executeB;
        private System.Windows.Forms.Label collationL;
        private System.Windows.Forms.Label databaseL;
        private System.Windows.Forms.Label passwordL;
        private System.Windows.Forms.Label userIdL;
        private System.Windows.Forms.Label serverL;
        private System.Windows.Forms.TextBox passwordE;
        private System.Windows.Forms.TextBox userIdE;
        private System.Windows.Forms.CheckBox integratedE;
        private System.Windows.Forms.TextBox databaseE;
        private System.Windows.Forms.TextBox serverE;
        private System.Windows.Forms.CheckBox singleUserE;
        private System.Windows.Forms.Timer cancelTimer;

        /// <summary>
        ///     Required method for Designer support - do not modify
        ///     the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            this.cancelB = new System.Windows.Forms.Button();
            this.languageE = new System.Windows.Forms.ComboBox();
            this.languageL = new System.Windows.Forms.Label();
            this.dropAllE = new System.Windows.Forms.CheckBox();
            this.labelNote2 = new System.Windows.Forms.Label();
            this.labelNote1 = new System.Windows.Forms.Label();
            this.collationE = new System.Windows.Forms.ComboBox();
            this.progressBar = new System.Windows.Forms.ProgressBar();
            this.scriptB = new System.Windows.Forms.Button();
            this.feedbackL = new System.Windows.Forms.RichTextBox();
            this.executeB = new System.Windows.Forms.Button();
            this.collationL = new System.Windows.Forms.Label();
            this.databaseL = new System.Windows.Forms.Label();
            this.passwordL = new System.Windows.Forms.Label();
            this.userIdL = new System.Windows.Forms.Label();
            this.serverL = new System.Windows.Forms.Label();
            this.passwordE = new System.Windows.Forms.TextBox();
            this.userIdE = new System.Windows.Forms.TextBox();
            this.integratedE = new System.Windows.Forms.CheckBox();
            this.databaseE = new System.Windows.Forms.TextBox();
            this.serverE = new System.Windows.Forms.TextBox();
            this.cancelTimer = new System.Windows.Forms.Timer(this.components);
            this.singleUserE = new System.Windows.Forms.CheckBox();
            this.SuspendLayout();
            // 
            // cancelB
            // 
            this.cancelB.Location = new System.Drawing.Point(240, 211);
            this.cancelB.Name = "cancelB";
            this.cancelB.Size = new System.Drawing.Size(88, 24);
            this.cancelB.TabIndex = 41;
            this.cancelB.Text = "Cancel";
            this.cancelB.Click += new System.EventHandler(this.cancelB_Click);
            // 
            // languageE
            // 
            this.languageE.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.languageE.Location = new System.Drawing.Point(144, 160);
            this.languageE.Name = "languageE";
            this.languageE.Size = new System.Drawing.Size(184, 21);
            this.languageE.TabIndex = 40;
            this.languageE.DropDown += new System.EventHandler(this.languageE_DropDown);
            // 
            // languageL
            // 
            this.languageL.Location = new System.Drawing.Point(5, 163);
            this.languageL.Name = "languageL";
            this.languageL.Size = new System.Drawing.Size(120, 16);
            this.languageL.TabIndex = 39;
            this.languageL.Text = "Full Text Language:";
            // 
            // dropAllE
            // 
            this.dropAllE.ImageAlign = System.Drawing.ContentAlignment.TopLeft;
            this.dropAllE.Location = new System.Drawing.Point(336, 144);
            this.dropAllE.Name = "dropAllE";
            this.dropAllE.Size = new System.Drawing.Size(256, 32);
            this.dropAllE.TabIndex = 38;
            this.dropAllE.Text = "Drop All Keys and Constraints.  (By Default only the required items are dropped)";
            this.dropAllE.TextAlign = System.Drawing.ContentAlignment.TopLeft;
            // 
            // labelNote2
            // 
            this.labelNote2.Location = new System.Drawing.Point(336, 88);
            this.labelNote2.Name = "labelNote2";
            this.labelNote2.Size = new System.Drawing.Size(256, 56);
            this.labelNote2.TabIndex = 35;
            this.labelNote2.Text = "NOTE: Once the script has been executed you will see any error messages shown in " +
                                   "red in the window below directly after the SQL code that failed";
            // 
            // labelNote1
            // 
            this.labelNote1.Location = new System.Drawing.Point(336, 8);
            this.labelNote1.Name = "labelNote1";
            this.labelNote1.Size = new System.Drawing.Size(256, 80);
            this.labelNote1.TabIndex = 34;
            this.labelNote1.Text = "NOTE: If you change from a case insensitive to a case sensitive collation order y" +
                                   "ou may find errors occur when recreating functions and check constraints - this " +
                                   "is because your SQL code will be parsed in a case sensitive manner.";
            // 
            // collationE
            // 
            this.collationE.Location = new System.Drawing.Point(144, 133);
            this.collationE.Name = "collationE";
            this.collationE.Size = new System.Drawing.Size(184, 21);
            this.collationE.TabIndex = 31;
            this.collationE.DropDown += new System.EventHandler(this.collationE_DropDown);
            // 
            // progressBar
            // 
            this.progressBar.Anchor =
            ((System.Windows.Forms.AnchorStyles)
            (((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
              | System.Windows.Forms.AnchorStyles.Right)));
            this.progressBar.Location = new System.Drawing.Point(8, 251);
            this.progressBar.Name = "progressBar";
            this.progressBar.Size = new System.Drawing.Size(584, 23);
            this.progressBar.TabIndex = 36;
            // 
            // scriptB
            // 
            this.scriptB.Location = new System.Drawing.Point(128, 211);
            this.scriptB.Name = "scriptB";
            this.scriptB.Size = new System.Drawing.Size(104, 24);
            this.scriptB.TabIndex = 33;
            this.scriptB.Text = "Script Only";
            this.scriptB.Click += new System.EventHandler(this.scriptB_Click);
            // 
            // feedbackL
            // 
            this.feedbackL.Anchor =
            ((System.Windows.Forms.AnchorStyles)
            ((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom)
               | System.Windows.Forms.AnchorStyles.Left)
              | System.Windows.Forms.AnchorStyles.Right)));
            this.feedbackL.DetectUrls = false;
            this.feedbackL.Location = new System.Drawing.Point(8, 291);
            this.feedbackL.Name = "feedbackL";
            this.feedbackL.ReadOnly = true;
            this.feedbackL.Size = new System.Drawing.Size(584, 152);
            this.feedbackL.TabIndex = 37;
            this.feedbackL.Text = "";
            // 
            // executeB
            // 
            this.executeB.Location = new System.Drawing.Point(8, 211);
            this.executeB.Name = "executeB";
            this.executeB.Size = new System.Drawing.Size(112, 24);
            this.executeB.TabIndex = 32;
            this.executeB.Text = "Script and Execute";
            this.executeB.Click += new System.EventHandler(this.executeB_Click);
            // 
            // collationL
            // 
            this.collationL.Location = new System.Drawing.Point(8, 136);
            this.collationL.Name = "collationL";
            this.collationL.Size = new System.Drawing.Size(120, 16);
            this.collationL.TabIndex = 30;
            this.collationL.Text = "Collation:";
            // 
            // databaseL
            // 
            this.databaseL.Location = new System.Drawing.Point(8, 110);
            this.databaseL.Name = "databaseL";
            this.databaseL.Size = new System.Drawing.Size(120, 16);
            this.databaseL.TabIndex = 28;
            this.databaseL.Text = "Database:";
            // 
            // passwordL
            // 
            this.passwordL.Enabled = false;
            this.passwordL.Location = new System.Drawing.Point(8, 84);
            this.passwordL.Name = "passwordL";
            this.passwordL.Size = new System.Drawing.Size(120, 16);
            this.passwordL.TabIndex = 26;
            this.passwordL.Text = "Password:";
            // 
            // userIdL
            // 
            this.userIdL.Enabled = false;
            this.userIdL.Location = new System.Drawing.Point(8, 59);
            this.userIdL.Name = "userIdL";
            this.userIdL.Size = new System.Drawing.Size(120, 16);
            this.userIdL.TabIndex = 24;
            this.userIdL.Text = "User ID:";
            // 
            // serverL
            // 
            this.serverL.Location = new System.Drawing.Point(8, 11);
            this.serverL.Name = "serverL";
            this.serverL.Size = new System.Drawing.Size(120, 16);
            this.serverL.TabIndex = 21;
            this.serverL.Text = "Server:";
            // 
            // passwordE
            // 
            this.passwordE.Enabled = false;
            this.passwordE.Location = new System.Drawing.Point(144, 81);
            this.passwordE.Name = "passwordE";
            this.passwordE.Size = new System.Drawing.Size(184, 20);
            this.passwordE.TabIndex = 27;
            this.passwordE.Text = "";
            // 
            // userIdE
            // 
            this.userIdE.Enabled = false;
            this.userIdE.Location = new System.Drawing.Point(144, 55);
            this.userIdE.Name = "userIdE";
            this.userIdE.Size = new System.Drawing.Size(184, 20);
            this.userIdE.TabIndex = 25;
            this.userIdE.Text = "";
            // 
            // integratedE
            // 
            this.integratedE.Checked = true;
            this.integratedE.CheckState = System.Windows.Forms.CheckState.Checked;
            this.integratedE.Location = new System.Drawing.Point(144, 29);
            this.integratedE.Name = "integratedE";
            this.integratedE.Size = new System.Drawing.Size(184, 24);
            this.integratedE.TabIndex = 23;
            this.integratedE.Text = "Integrated Security";
            this.integratedE.CheckedChanged += new System.EventHandler(this.integratedE_CheckedChanged);
            // 
            // databaseE
            // 
            this.databaseE.Location = new System.Drawing.Point(144, 107);
            this.databaseE.Name = "databaseE";
            this.databaseE.Size = new System.Drawing.Size(184, 20);
            this.databaseE.TabIndex = 29;
            this.databaseE.Text = "";
            // 
            // serverE
            // 
            this.serverE.Location = new System.Drawing.Point(144, 11);
            this.serverE.Name = "serverE";
            this.serverE.Size = new System.Drawing.Size(184, 20);
            this.serverE.TabIndex = 22;
            this.serverE.Text = "";
            this.serverE.TextChanged += new System.EventHandler(this.serverE_TextChanged);
            // 
            // cancelTimer
            // 
            this.cancelTimer.Interval = 5000;
            this.cancelTimer.Tick += new System.EventHandler(this.cancelTimer_Tick);
            // 
            // singleUserE
            // 
            this.singleUserE.Checked = true;
            this.singleUserE.CheckState = System.Windows.Forms.CheckState.Checked;
            this.singleUserE.Location = new System.Drawing.Point(336, 184);
            this.singleUserE.Name = "singleUserE";
            this.singleUserE.Size = new System.Drawing.Size(256, 48);
            this.singleUserE.TabIndex = 42;
            this.singleUserE.Text =
                "Switch database to single user mode while running script.  This is the safest opt" +
                "ion but does not work with database mirroring.";
            // 
            // MainForm
            // 
            this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
            this.ClientSize = new System.Drawing.Size(600, 454);
            this.Controls.Add(this.singleUserE);
            this.Controls.Add(this.cancelB);
            this.Controls.Add(this.languageE);
            this.Controls.Add(this.languageL);
            this.Controls.Add(this.dropAllE);
            this.Controls.Add(this.labelNote2);
            this.Controls.Add(this.labelNote1);
            this.Controls.Add(this.collationE);
            this.Controls.Add(this.progressBar);
            this.Controls.Add(this.scriptB);
            this.Controls.Add(this.feedbackL);
            this.Controls.Add(this.executeB);
            this.Controls.Add(this.collationL);
            this.Controls.Add(this.databaseL);
            this.Controls.Add(this.passwordL);
            this.Controls.Add(this.userIdL);
            this.Controls.Add(this.serverL);
            this.Controls.Add(this.passwordE);
            this.Controls.Add(this.userIdE);
            this.Controls.Add(this.integratedE);
            this.Controls.Add(this.databaseE);
            this.Controls.Add(this.serverE);
            this.Name = "MainForm";
            this.Text = "Change Collation";
            this.ResumeLayout(false);
        }

        #endregion

        #region IScriptExecuteCallback Members

        bool IScriptExecuteCallback.Error(ScriptStep step, Exception exception)
        {
            return (bool) Invoke(new ScriptErrorCallback(ScriptError), step, exception);
        }

        bool IScriptExecuteCallback.Progress(ScriptStep script, int step, int stepMax)
        {
            if (!canceled)
                BeginInvoke(new UpdateUICallback(UpdateUI), step);
            return !canceled;
        }

        void IScriptExecuteCallback.ExecutionStarting(ScriptStepCollection script)
        {
            lock (this)
            {
                executingScript = script;
                lastReportedStep = -1;
            }
        }

        #endregion
    }
}