package edu.bnbu.student.mvp.feature.exemption

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import edu.bnbu.student.mvp.core.data.ApiStudentRepository
import edu.bnbu.student.mvp.core.designsystem.ActionButton
import edu.bnbu.student.mvp.core.designsystem.BNBUColors
import edu.bnbu.student.mvp.core.designsystem.EmptyPlaceholder
import edu.bnbu.student.mvp.core.designsystem.SectionTitle
import edu.bnbu.student.mvp.core.designsystem.SegmentedControl
import edu.bnbu.student.mvp.core.designsystem.StatusBadge
import edu.bnbu.student.mvp.core.designsystem.StatusMessagePanel
import edu.bnbu.student.mvp.core.designsystem.SwissPanel
import edu.bnbu.student.mvp.core.designsystem.ValidationPanel
import edu.bnbu.student.mvp.core.model.Exemption
import edu.bnbu.student.mvp.core.model.ExemptionApplication
import edu.bnbu.student.mvp.core.model.ExemptionType
import kotlinx.coroutines.launch

private enum class ExemptionTab(val label: String) {
    MyApplications("我的申请"),
    NewApplication("提交申请")
}

@Composable
fun ExemptionScreen(
    repository: ApiStudentRepository,
    onBack: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(ExemptionTab.MyApplications) }
    var exemptions by remember { mutableStateOf<List<Exemption>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var successMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun loadExemptions() {
        isLoading = true
        scope.launch {
            try {
                val response = repository.listExemptions()
                exemptions = response.map { r ->
                    Exemption(
                        id = r.id,
                        studentId = r.studentId,
                        studentName = r.studentName,
                        type = r.type,
                        reason = r.reason ?: "",
                        status = r.status,
                        proofFiles = r.proofFiles,
                        reviewComment = r.reviewComment ?: "",
                        reviewerId = r.reviewerId ?: "",
                        reviewerName = r.reviewerName ?: "",
                        createdAt = r.createdAt,
                        updatedAt = r.updatedAt ?: ""
                    )
                }
            } catch (e: Exception) {
                errorMessage = "加载失败: ${e.message}"
            } finally {
                isLoading = false
            }
        }
    }

    // Load on first composition — safely managed by LaunchedEffect lifecycle
    LaunchedEffect(Unit) {
        if (exemptions.isEmpty() && !isLoading) {
            loadExemptions()
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onBack)
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = null,
                    tint = BNBUColors.Ink
                )
                Text(
                    text = "返回",
                    color = BNBUColors.Ink,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Black
                )
            }
        }

        item {
            SectionTitle(
                eyebrow = "Exemption",
                title = "800m / 1000m 免测申请"
            )
        }

        item {
            SegmentedControl(
                values = ExemptionTab.entries,
                selected = selectedTab,
                label = { it.label },
                onSelected = { selectedTab = it }
            )
        }

        if (successMessage != null) {
            item {
                val msg = successMessage!!
                StatusMessagePanel(
                    message = msg,
                    onDismiss = { successMessage = null }
                )
            }
        }

        if (errorMessage != null) {
            item {
                val msg = errorMessage!!
                ValidationPanel(message = msg)
            }
        }

        when (selectedTab) {
            ExemptionTab.MyApplications -> {
                if (exemptions.isEmpty()) {
                    item {
                        EmptyPlaceholder(
                            title = "暂无免测申请",
                            message = "你还没有提交过免测申请。请切换到「提交申请」标签页提交新的申请。"
                        )
                    }
                } else {
                    exemptions.forEach { exemption ->
                        item {
                            ExemptionCard(exemption)
                        }
                    }
                }
            }

            ExemptionTab.NewApplication -> {
                item {
                    NewExemptionForm(
                        repository = repository,
                        onSuccess = { msg ->
                            successMessage = msg
                            selectedTab = ExemptionTab.MyApplications
                            loadExemptions()
                        },
                        onError = { errorMessage = it }
                    )
                }
            }
        }
    }
}

@Composable
private fun ExemptionCard(exemption: Exemption) {
    val statusColor = when (exemption.status) {
        "已通过" -> BNBUColors.Blue
        "已驳回" -> Color(0xFFF44336)
        else -> Color(0xFFFF9800)
    }

    SwissPanel {
        Row(verticalAlignment = Alignment.Top) {
            Icon(
                imageVector = Icons.Filled.FitnessCenter,
                contentDescription = null,
                tint = BNBUColors.Blue,
                modifier = Modifier.size(22.dp)
            )
            Spacer(Modifier.width(10.dp))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = exemption.typeLabel,
                        color = BNBUColors.Ink,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Black,
                        modifier = Modifier.weight(1f)
                    )
                    StatusBadge(text = exemption.status, filled = exemption.status == "已通过")
                }

                if (exemption.reason.isNotBlank()) {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(
                            imageVector = Icons.Filled.Description,
                            contentDescription = null,
                            tint = BNBUColors.Muted,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            text = exemption.reason,
                            color = BNBUColors.Muted,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            lineHeight = 20.sp
                        )
                    }
                }

                if (exemption.proofFiles.isNotEmpty()) {
                    Text(
                        text = "已上传 ${exemption.proofFiles.size} 个证明文件",
                        color = BNBUColors.Blue,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                if (exemption.reviewComment.isNotBlank()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(BNBUColors.BlueSoft)
                            .border(1.dp, BNBUColors.Line, RectangleShape)
                            .padding(10.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Warning,
                            contentDescription = null,
                            tint = BNBUColors.Blue,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Column {
                            Text(
                                text = "审核意见",
                                color = BNBUColors.Ink,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Black
                            )
                            Text(
                                text = exemption.reviewComment,
                                color = BNBUColors.Muted,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }

                Text(
                    text = "提交时间: ${exemption.createdAt}",
                    color = BNBUColors.Muted,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun NewExemptionForm(
    repository: ApiStudentRepository,
    onSuccess: (String) -> Unit,
    onError: (String) -> Unit
) {
    var selectedType by remember { mutableStateOf(ExemptionType.Run800) }
    var reason by remember { mutableStateOf("") }
    var proofFiles by remember { mutableStateOf(listOf<String>()) }
    var isSubmitting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    SwissPanel {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(
                text = "选择免测项目",
                color = BNBUColors.Muted,
                fontSize = 12.sp,
                fontWeight = FontWeight.Black
            )
            SegmentedControl(
                values = ExemptionType.entries,
                selected = selectedType,
                label = { it.label },
                onSelected = { selectedType = it }
            )

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "申请理由",
                    color = BNBUColors.Muted,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Black
                )
                OutlinedTextField(
                    value = reason,
                    onValueChange = { reason = it },
                    placeholder = { Text("请说明申请免测的原因...") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    maxLines = 6
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "证明材料",
                        color = BNBUColors.Muted,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Black,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "${proofFiles.size} 个文件",
                        color = BNBUColors.Muted,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                // Note: file upload via camera/gallery would be handled by platform-specific
                // image picker integration. This is a placeholder for the proof file list.
                if (proofFiles.isNotEmpty()) {
                    proofFiles.forEach { file ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(BNBUColors.BlueSoft)
                                .border(1.dp, BNBUColors.Line, RectangleShape)
                                .padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Filled.FileUpload,
                                contentDescription = null,
                                tint = BNBUColors.Blue,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = file,
                                color = BNBUColors.Ink,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.weight(1f)
                            )
                            Icon(
                                imageVector = Icons.Filled.Clear,
                                contentDescription = "移除",
                                tint = BNBUColors.Muted,
                                modifier = Modifier
                                    .size(18.dp)
                                    .clickable { proofFiles = proofFiles - file }
                            )
                        }
                    }
                } else {
                    Text(
                        text = "证明材料为可选。如需上传，请使用拍照或相册功能（接入后可用）。",
                        color = BNBUColors.Muted,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        lineHeight = 18.sp
                    )
                }
            }

            ActionButton(
                title = if (isSubmitting) "提交中..." else "提交免测申请",
                icon = Icons.Filled.Add,
                filled = true,
                onClick = {
                    if (reason.isBlank()) {
                        onError("请填写申请理由")
                        return@ActionButton
                    }
                    isSubmitting = true
                    scope.launch {
                        try {
                            val response = repository.submitExemption(
                                ExemptionApplication(
                                    type = selectedType.label,
                                    reason = reason,
                                    proofFiles = proofFiles
                                )
                            )
                            onSuccess("免测申请已提交 (${response.id})")
                        } catch (e: Exception) {
                            onError("提交失败: ${e.message}")
                        } finally {
                            isSubmitting = false
                        }
                    }
                }
            )
        }
    }
}
